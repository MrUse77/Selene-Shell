#!/usr/bin/env python3
"""Focused static regression checks for the first Selene correction work unit.

These checks intentionally do not claim to prove compositor/runtime pointer routing.
They enforce the QML source structure needed for the bounded fixes without launching
Quickshell or interacting with the desktop session.
"""

from pathlib import Path
import re
import subprocess
import unittest


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MOON_QML = PROJECT_ROOT / "Services" / "Moon.qml"
NOTIFICATIONS_QML = PROJECT_ROOT / "Modules" / "Notifications" / "Notifications.qml"
SHELL_STATE_QML = PROJECT_ROOT / "Services" / "ShellState.qml"
OVERLAY_COORDINATOR_QML = PROJECT_ROOT / "Services" / "OverlayCoordinator.qml"
SERVICES_QMLDIR = PROJECT_ROOT / "Services" / "qmldir"
SHELL_QML = PROJECT_ROOT / "shell.qml"
LAUNCHER_QML = PROJECT_ROOT / "Modules" / "Launcher" / "Launcher.qml"
DASHBOARD_QML = PROJECT_ROOT / "Modules" / "Dashboard" / "Dashboard.qml"
POWER_MENU_QML = PROJECT_ROOT / "Modules" / "PowerMenu" / "PowerMenu.qml"


class SeleneCorrectionContracts(unittest.TestCase):
    def test_moon_has_no_qmllint_unqualified_access(self) -> None:
        result = subprocess.run(
            [
                "/usr/lib/qt6/bin/qmllint",
                "-I",
                "/usr/lib/qt6/qml",
                "-i",
                "/usr/lib/qt6/qml/QtQml/plugins.qmltypes",
                str(MOON_QML),
            ],
            cwd=PROJECT_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        diagnostics = result.stdout + result.stderr
        self.assertEqual(
            result.returncode,
            0,
            f"Moon.qml must pass the actionable qmllint check:\n{diagnostics}",
        )
    def test_critical_notification_timer_does_not_use_infinity(self) -> None:
        source = NOTIFICATIONS_QML.read_text(encoding="utf-8")
        self.assertFalse(
            "Infinity" in source,
            "A QML Timer interval is an integer and must not be assigned Infinity",
        )
    def test_critical_notification_timer_is_disabled(self) -> None:
        source = NOTIFICATIONS_QML.read_text(encoding="utf-8")
        critical_timer_disabled = re.search(
            r"Timer\s*\{.*?running\s*:\s*!popup\.critical", source, re.DOTALL
        )
        self.assertIsNotNone(
            critical_timer_disabled,
            "Critical notifications must disable their expiration Timer",
        )
    def test_notification_timer_uses_expire_timeout_milliseconds_directly(self) -> None:
        source = NOTIFICATIONS_QML.read_text(encoding="utf-8")
        timer = re.search(r"Timer\s*\{.*?running\s*:\s*!popup\.critical", source, re.DOTALL)
        self.assertIsNotNone(timer, "Notification expiration Timer contract is missing")
        timer_source = timer.group(0)
        self.assertNotRegex(
            timer_source,
            r"expireTimeout\s*\*\s*1000",
            "expireTimeout is already milliseconds and must not be multiplied",
        )
        self.assertRegex(
            timer_source,
            r"interval\s*:\s*popup\.n\.expireTimeout\s*>\s*0\s*"
            r"\?\s*popup\.n\.expireTimeout\s*:\s*5000",
            "Positive expireTimeout must be used directly with a finite 5000 ms fallback",
        )
    def test_popup_dismiss_layer_precedes_action_content(self) -> None:
        source = NOTIFICATIONS_QML.read_text(encoding="utf-8")
        dismiss = re.search(
            r"MouseArea\s*\{\s*anchors\.fill:\s*parent\s*"
            r"onClicked:\s*root\.closeNotif\(popup\.n, popup\.uid\)\s*\}",
            source,
        )
        content = re.search(r"Column\s*\{\s*id:\s*contentCol\b", source)
        self.assertIsNotNone(dismiss, "Popup-wide dismiss MouseArea contract is missing")
        self.assertIsNotNone(content, "Popup action content contract is missing")
        self.assertLess(
            dismiss.start(),
            content.start(),
            "Popup-wide dismiss MouseArea must be declared before action content so "
            "the later action controls remain above it in sibling stacking order",
        )
    def test_overlay_coordinator_state_is_private_and_barrier_free(self) -> None:
        source = OVERLAY_COORDINATOR_QML.read_text(encoding="utf-8")
        self.assertRegex(source, r"property\s+string\s+_activeKind\s*:")
        self.assertRegex(source, r"property\s+var\s+_targetScreen\s*:")
        for token in ("_screenReady", "_readyGeneration", "screenReady", "_markReady", "Qt.callLater"):
            self.assertNotIn(token, source, f"OverlayCoordinator must not retain barrier token {token!r}")
    def test_overlay_coordinator_public_projections_are_readonly(self) -> None:
        source = OVERLAY_COORDINATOR_QML.read_text(encoding="utf-8")
        for name in ("activeKind", "targetScreen", "launcherOpen", "dashboardOpen", "powerOpen"):
            self.assertRegex(source, rf"readonly\s+property\s+\w+\s+{name}\b")
    def test_qmldir_registers_overlay_coordinator_singleton(self) -> None:
        self.assertIn(
            "singleton OverlayCoordinator OverlayCoordinator.qml",
            SERVICES_QMLDIR.read_text(encoding="utf-8"),
        )
    def test_shell_state_no_longer_declares_overlay_booleans(self) -> None:
        source = SHELL_STATE_QML.read_text(encoding="utf-8")
        for name in ("launcherOpen", "dashboardOpen", "powerOpen", "toggleLauncher", "toggleDashboard", "togglePower"):
            self.assertNotIn(name, source)
    def test_no_external_assignment_to_coordinator_private_state(self) -> None:
        for path in PROJECT_ROOT.rglob("*.qml"):
            if path.name == "OverlayCoordinator.qml":
                continue
            source = path.read_text(encoding="utf-8")
            for prop in ("_activeKind", "_targetScreen", "activeKind", "targetScreen"):
                self.assertNotRegex(
                    source,
                    rf"OverlayCoordinator\.{prop}\s*=[^=]",
                    f"{path.name} must not assign OverlayCoordinator.{prop}",
                )
    def test_shell_qml_instantiates_each_overlay_via_variants_over_screens(self) -> None:
        source = SHELL_QML.read_text(encoding="utf-8")
        for kind in ("Launcher", "Dashboard", "PowerMenu"):
            self.assertRegex(
                source,
                rf"Variants\s*\{{\s*model:\s*Quickshell\.screens\s*{kind}\s*\{{\s*\}}\s*\}}",
                f"{kind} must be instantiated through a Variants composition over Quickshell.screens",
            )
    def test_overlay_modules_bind_fixed_screen_to_modelData(self) -> None:
        for path in (LAUNCHER_QML, DASHBOARD_QML, POWER_MENU_QML):
            source = path.read_text(encoding="utf-8")
            self.assertRegex(source, r"\bproperty\s+var\s+modelData\b", f"{path.name} must declare modelData")
            self.assertIn("screen: modelData", source, f"{path.name} must bind screen to modelData")
    def test_overlay_visibility_and_focus_gated_by_kind_and_target_identity(self) -> None:
        for path, kind in ((LAUNCHER_QML, "launcher"), (DASHBOARD_QML, "dashboard"), (POWER_MENU_QML, "power")):
            source = path.read_text(encoding="utf-8")
            gate = rf"OverlayCoordinator\.{kind}Open\s*&&\s*OverlayCoordinator\.targetScreen\s*===\s*modelData"
            self.assertRegex(source, rf"visible:\s*{gate}", f"{path.name} visible must be gated")
            self.assertRegex(source, rf"focusable:\s*{gate}", f"{path.name} focusable must be gated")
    def test_shell_qml_ipc_uses_coordinator_for_overlay_toggles(self) -> None:
        source = SHELL_QML.read_text(encoding="utf-8")
        for kind in ("Launcher", "Dashboard", "Power"):
            self.assertRegex(
                source,
                rf"function\s+toggle{kind}\s*\(\)\s*\{{[^}}]*OverlayCoordinator\.resolveFocusedScreen\s*\(\)",
                f"toggle{kind} must resolve the focused screen",
            )
            self.assertRegex(
                source,
                rf"function\s+toggle{kind}\s*\(\)\s*\{{[^}}]*OverlayCoordinator\.toggle\s*\(",
                f"toggle{kind} must invoke OverlayCoordinator.toggle",
            )
    def test_overlay_coordinator_apply_orders_assignments(self) -> None:
        body = re.search(
            r"function\s+apply\s*\(\s*result\s*\)\s*\{([^{}]*(\{[^{}]*\}[^{}]*)*)\}",
            OVERLAY_COORDINATOR_QML.read_text(encoding="utf-8"),
        ).group(1)
        assignments = re.findall(r"\b(_activeKind|_targetScreen)\s*=", body)
        first_kind, first_target = assignments.index("_activeKind"), assignments.index("_targetScreen")
        last_kind = len(assignments) - 1 - assignments[::-1].index("_activeKind")
        last_target = len(assignments) - 1 - assignments[::-1].index("_targetScreen")
        self.assertLess(first_kind, first_target, "_activeKind must be cleared before _targetScreen")
        self.assertLess(last_target, last_kind, "_targetScreen must be assigned before final _activeKind")

    def test_launcher_resolves_desktop_icon_names_with_fallback(self) -> None:
        source = LAUNCHER_QML.read_text(encoding="utf-8")
        self.assertRegex(
            source,
            r"source\s*:\s*Quickshell\.iconPath\(\s*modelData\.icon\s*\?\?\s*\"\"\s*,\s*"
            r"\"application-x-executable\"\s*\)",
            "Desktop entry icon names must be resolved with an executable icon fallback",
        )

    def test_launcher_exposes_all_sorted_matching_results(self) -> None:
        source = LAUNCHER_QML.read_text(encoding="utf-8")
        self.assertRegex(
            source,
            r"results\s*=\s*scored\.map\(x\s*=>\s*x\.app\)",
            "Every sorted matching application must be exposed to the launcher ListView",
        )
        self.assertNotRegex(
            source,
            r"scored\.slice\(",
            "Launcher results must not be truncated by an arbitrary fixed cap",
        )

    def test_launcher_list_current_index_tracks_and_contains_keyboard_selection(self) -> None:
        source = LAUNCHER_QML.read_text(encoding="utf-8")
        self.assertRegex(
            source,
            r"(?s)ListView\s*\{.*?currentIndex:\s*root\.selected\b",
            "ListView.currentIndex must track root.selected",
        )
        self.assertRegex(
            source,
            r"(?s)ListView\s*\{.*?onCurrentIndexChanged\s*:\s*\{?\s*"
            r"(?:if\s*\([^)]*\)\s*)?"
            r"(?:list\.)?positionViewAtIndex\(\s*(?:list\.)?currentIndex\s*,\s*"
            r"ListView\.Contain\s*\)",
            "Every currentIndex change must explicitly keep the selected result in the viewport",
        )

    def test_launcher_delegate_declares_and_uses_required_index(self) -> None:
        source = LAUNCHER_QML.read_text(encoding="utf-8")
        self.assertRegex(
            source,
            r"delegate:\s*Rectangle\s*\{\s*id:\s*resultDelegate\s*"
            r"required\s+property\s+var\s+modelData\s*"
            r"required\s+property\s+int\s+index\b",
            "The launcher delegate must explicitly declare the ListView index role",
        )
        self.assertNotRegex(
            source,
            r"readonly\s+property\s+int\s+idx\s*:\s*index\b",
            "The broken implicit index bridge must not remain",
        )
        self.assertRegex(source, r"color:\s*resultDelegate\.index\s*===\s*root\.selected\b")
        self.assertRegex(source, r"border\.width:\s*resultDelegate\.index\s*===\s*root\.selected\b")
        self.assertRegex(source, r"onPositionChanged:\s*root\.selected\s*=\s*resultDelegate\.index\b")
        self.assertRegex(source, r"onClicked:\s*\{\s*root\.selected\s*=\s*resultDelegate\.index\s*;")


if __name__ == "__main__":
    unittest.main(verbosity=2)
