#!/usr/bin/env python3
"""Focused static regression checks for the first Selene correction work unit.

These checks intentionally do not claim to prove compositor/runtime pointer routing.
They enforce the QML source structure needed for the bounded fixes without launching
Quickshell or interacting with the desktop session.
"""

from pathlib import Path
import json
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
LAUNCHER_LOGIC_JS = PROJECT_ROOT / "Services" / "LauncherLogic.js"
OPERATION_STATE_JS = PROJECT_ROOT / "Services" / "OperationState.js"
THEME_QML = PROJECT_ROOT / "Services" / "Theme.qml"
SHELL_JSON = PROJECT_ROOT / "shell.json"
README = PROJECT_ROOT / "README.md"


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
            r"source\s*:\s*Quickshell\.iconPath\(\s*(?:resultDelegate\.)?modelData\.icon\s*\?\?\s*\"\"\s*,\s*"
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

    def test_launcher_exposes_migrated_modes_and_safe_processes(self) -> None:
        source = LAUNCHER_QML.read_text(encoding="utf-8")
        for mode in ("apps", "windows", "run", "themes"):
            self.assertIn(f'key: "{mode}"', source)
        self.assertIn("LauncherLogic.parseCommand", source)
        self.assertIn("Hyprland.toplevels.values", source)
        self.assertIn('Hyprland.dispatch("focuswindow address:"', source)
        self.assertIn('root.themeSelector, "--list"]', source)
        self.assertIn('"find", root.themesRoot', source)
        self.assertIn('[themeSelector, "--apply", item.themeId]', source)
        self.assertIn("Theme.reloadTheme()", source)
        self.assertIn('["wl-copy", calcResult]', source)

    def test_launcher_mode_button_text_is_explicitly_vertically_centered(self) -> None:
        source = LAUNCHER_QML.read_text(encoding="utf-8")
        mode_delegate = source[
            source.index("delegate: Capsule {") : source.index("HoverHandler { id: hover")
        ]
        content_start = mode_delegate.index("Row {")
        mode_content = mode_delegate[content_start:]

        self.assertRegex(mode_content, r"height\s*:\s*parent\.height\b")
        text_nodes = re.findall(r"Text\s*\{([^{}]*)\}", mode_content)
        self.assertEqual(len(text_nodes), 2, "The mode button must contain its icon and label Text nodes")
        for text_node in text_nodes:
            self.assertRegex(text_node, r"height\s*:\s*parent\.height\b")
            self.assertRegex(
                text_node,
                r"verticalAlignment\s*:\s*Text\.AlignVCenter\b",
            )

    def test_shell_ipc_has_canonical_migration_entry_points(self) -> None:
        source = SHELL_QML.read_text(encoding="utf-8")
        for method, mode in (
            ("openApps", "apps"),
            ("openWindows", "windows"),
            ("openRun", "run"),
            ("openThemes", "themes"),
        ):
            self.assertRegex(
                source,
                rf"function\s+{method}\s*\(\)\s*\{{[^}}]*openLauncher\(\"{mode}\"",
            )

    def test_power_menu_confirms_only_destructive_actions(self) -> None:
        source = POWER_MENU_QML.read_text(encoding="utf-8")
        self.assertIn('confirm: false, cmd: ["hyprlock"]', source)
        self.assertIn('confirm: false, cmd: ["systemctl", "suspend"]', source)
        for command in (
            '["hyprctl", "dispatch", "exit"]',
            '["systemctl", "reboot"]',
            '["systemctl", "poweroff"]',
        ):
            self.assertRegex(source, rf"confirm:\s*true,\s*cmd:\s*{re.escape(command)}")
        self.assertIn("onExited:", source)
        self.assertIn("stderr", source)

    def test_process_acceptance_has_busy_guards_identity_and_startup_watchdogs(self) -> None:
        launcher = LAUNCHER_QML.read_text(encoding="utf-8")
        power = POWER_MENU_QML.read_text(encoding="utf-8")
        for source in (launcher, power):
            self.assertIn("OperationState.begin", source)
            self.assertIn("OperationState.startupTimeout", source)
            self.assertRegex(source, r"if\s*\([^)]*(?:Busy|busy)[^)]*\)\s*return")
            self.assertRegex(source, re.compile(r"Timer\s*\{[^}]*startup", re.DOTALL | re.IGNORECASE))
            self.assertRegex(source, r"(?:===|!==)\s*process", "Completions must verify process identity")
        self.assertIn("closeOnStarted", power, "hyprlock needs successful-start close semantics")
        self.assertRegex(power, r"enabled:\s*!root\.operationBusy")
        self.assertRegex(launcher, r"enabled:\s*!root\.acceptanceBusy")

    def test_overlay_sessions_guard_async_closures(self) -> None:
        coordinator = OVERLAY_COORDINATOR_QML.read_text(encoding="utf-8")
        launcher = LAUNCHER_QML.read_text(encoding="utf-8")
        power = POWER_MENU_QML.read_text(encoding="utf-8")
        self.assertRegex(coordinator, r"readonly\s+property\s+int\s+sessionGeneration\b")
        self.assertRegex(coordinator, r"function\s+closeSession\s*\(")
        self.assertIn("OverlayState.matchesSession", coordinator)
        self.assertIn("function setLauncherMode", coordinator)
        self.assertIn("OverlayCoordinator.setLauncherMode", launcher)
        self.assertIn("OverlayCoordinator.closeSession", launcher)
        self.assertIn("OverlayCoordinator.closeSession", power)
        for source in (launcher, power):
            for name in ("sessionKind", "sessionScreen", "sessionGeneration"):
                self.assertRegex(source, rf"required\s+property\s+\w+\s+{name}\b")

    def test_process_startup_success_comes_only_from_on_started(self) -> None:
        launcher = LAUNCHER_QML.read_text(encoding="utf-8")
        power = POWER_MENU_QML.read_text(encoding="utf-8")
        for source, callbacks in (
            (launcher, ("commandStarted", "themeListStarted", "themeApplyStarted")),
            (power, ("actionStarted",)),
        ):
            for callback in callbacks:
                calls = re.findall(rf"\b{callback}\s*\(", source)
                self.assertEqual(
                    len(calls), 2,
                    f"{callback} must be declared once and called only by Process.onStarted",
                )
            self.assertNotRegex(
                source,
                re.compile(r"onTriggered\s*:\s*\{.*?\.running.*?Started\s*\(", re.DOTALL),
                "Process.running is allocated before QProcess::started and cannot prove startup",
            )

    def test_started_long_lived_processes_are_retained_without_release_timers(self) -> None:
        launcher = LAUNCHER_QML.read_text(encoding="utf-8")
        power = POWER_MENU_QML.read_text(encoding="utf-8")
        self.assertNotIn("commandReleaseWatchdog", launcher)
        self.assertNotIn("actionReleaseWatchdog", power)
        self.assertNotRegex(launcher, r"interval\s*:\s*250\b")
        self.assertNotRegex(power, r"interval\s*:\s*250\b")
        self.assertRegex(launcher, r"function\s+commandStarted\b[\s\S]*?commandProcess\s*=\s*null")
        self.assertRegex(power, r"function\s+actionStarted\b[\s\S]*?actionProcess\s*=\s*null")
        self.assertIn('["notify-send"', launcher)
        self.assertIn('["notify-send"', power)

    def test_theme_load_invalidation_cancels_wrapper_before_releasing_ownership(self) -> None:
        source = LAUNCHER_QML.read_text(encoding="utf-8")
        start = source.index("function invalidateThemeLoad()")
        end = source.index("function loadThemes()", start)
        text = source[start:end]
        stop = text.index("themeListStartupWatchdog.stop()")
        cancel = text.index("process.running = false")
        destroy = text.index("process.destroy()")
        release = text.index("themeListProcess = null")
        self.assertLess(stop, cancel)
        self.assertLess(cancel, destroy)
        self.assertLess(destroy, release)

    def test_launcher_reacts_to_same_open_mode_switch(self) -> None:
        source = LAUNCHER_QML.read_text(encoding="utf-8")
        self.assertRegex(
            source,
            re.compile(
                r"Connections\s*\{\s*target:\s*OverlayCoordinator.*?"
                r"onLauncherModeChanged\s*\([^)]*\)\s*\{[^}]*"
                r"if\s*\(root\.visible\)[^}]*root\.setMode\(",
                re.DOTALL,
            ),
            "A launcher already visible must consume same-kind IPC mode changes",
        )

    def test_theme_command_resolution_is_configurable_not_hardcoded(self) -> None:
        """El comando de temas se resuelve por la cadena configurable, no como literal (tarea 4.1)."""
        source = LAUNCHER_QML.read_text(encoding="utf-8")
        self.assertRegex(
            source,
            r"readonly\s+property\s+string\s+themeSelector\s*:\s*Theme\.pick\(",
            "themeSelector debe resolverse mediante Theme.pick con la cadena de D3",
        )
        self.assertRegex(
            source,
            r'Quickshell\.env\("SHELL_THEME_COMMAND"\)',
            "La cadena debe empezar por la variable de entorno de nombre neutro",
        )
        self.assertRegex(
            source,
            r'Quickshell\.env\("MOONARCH_THEME_COMMAND"\)',
            "El alias de compatibilidad de moonarch debe seguir aceptándose",
        )
        self.assertRegex(
            source,
            r"Theme\.settingsThemeCommand",
            "El comando debe poder venir del archivo de settings de la shell",
        )
        self.assertNotRegex(
            source,
            r'themeSelector\s*:\s*Quickshell\.env\("HOME"\)\s*\+',
            "El comando de temas no puede declararse como literal concatenando $HOME",
        )
        self.assertNotIn(
            "moonarch/theme-selector",
            source,
            "El path del selector de moonarch no debe vivir como literal en Launcher.qml",
        )
        theme_source = THEME_QML.read_text(encoding="utf-8")
        self.assertRegex(
            theme_source,
            r'readonly\s+property\s+string\s+defaultThemeCommand\s*:\s*'
            r'Quickshell\.env\("HOME"\)\s*\+\s*"/\.local/bin/moonarch/theme-selector"',
            "El default de moonarch debe conservarse como default, no como requisito",
        )
        self.assertRegex(
            theme_source,
            r"readonly\s+property\s+string\s+settingsThemeCommand",
            "Theme debe exponer el valor de settings para el comando de temas",
        )

    def test_themes_root_resolution_is_neutral_first_with_moonarch_alias(self) -> None:
        """La raíz de temas se resuelve neutro primero, con alias y default de moonarch (tareas 1.2/1.3)."""
        theme_source = THEME_QML.read_text(encoding="utf-8")
        self.assertIn('Quickshell.env("SHELL_THEMES_ROOT")', theme_source)
        self.assertIn('Quickshell.env("MOONARCH_THEMES_ROOT")', theme_source)
        neutral = theme_source.index('Quickshell.env("SHELL_THEMES_ROOT")')
        alias = theme_source.index('Quickshell.env("MOONARCH_THEMES_ROOT")')
        self.assertLess(neutral, alias, "El nombre neutro debe preceder al alias de moonarch")
        self.assertRegex(theme_source, r"readonly\s+property\s+string\s+settingsThemesRoot")
        self.assertIn('"/.local/share/moonarch/themes"', theme_source)
        shell_settings = json.loads(SHELL_JSON.read_text(encoding="utf-8"))
        for key in ("themesRoot", "themeCommand"):
            self.assertIn(key, shell_settings, f"shell.json debe declarar {key}")
            value = shell_settings[key]
            self.assertTrue(
                value is None or isinstance(value, str),
                f"{key} debe ser null (usa el default) o un string configurable",
            )

    def test_theme_mode_degrades_to_readonly_listing_without_provider(self) -> None:
        """Sin comando de temas el modo Themes lista en lectura y explica que falta un proveedor (tarea 4.2)."""
        source = LAUNCHER_QML.read_text(encoding="utf-8")
        self.assertRegex(source, r"readonly\s+property\s+bool\s+themeCommandAvailable\b")
        self.assertRegex(source, r"property\s+bool\s+themeListReadOnly\b")
        load_body = re.search(r"function\s+loadThemes\s*\(\)\s*\{(.*?)\n    \}", source, re.DOTALL)
        self.assertIsNotNone(load_body)
        body = load_body.group(1)
        self.assertRegex(body, r"themeListReadOnly\s*=\s*!root\.themeCommandAvailable")
        self.assertRegex(body, r"themeListReadOnly\s*\?\s*")
        self.assertIn("theme provider", body)
        self.assertRegex(
            source,
            r"if\s*\(themeListReadOnly\)\s*return",
            "El modo lectura no debe intentar aplicar temas",
        )
        # El orden del ternario es parte del contrato: sin este anclaje, un
        # ternario invertido pasaria porque cada argv ya se assertea por
        # separado en otro contrato.
        ternary = re.search(
            r"process\.exec\(\s*themeListReadOnly\s*\?\s*"
            r"(?P<readonly_argv>\[[^\]]*\])\s*:\s*"
            r"(?P<provider_argv>\[[^\]]*\])\s*\)",
            body,
            re.DOTALL,
        )
        self.assertIsNotNone(
            ternary,
            "El exec del listado debe elegir el argv con el ternario themeListReadOnly",
        )
        self.assertIn(
            '"find", root.themesRoot',
            ternary.group("readonly_argv"),
            "La rama verdadera del ternario debe ser el listado find sobre themesRoot",
        )
        self.assertIn(
            '[root.themeSelector, "--list"]',
            ternary.group("provider_argv"),
            "La rama falsa del ternario debe ser el --list del proveedor",
        )
        # El caso sin proveedor no puede quedar cargando: el handler de
        # salida limpia themesLoading antes de ramificar por modo lectura.
        exited_body = re.search(
            r"function\s+themeListExited\s*\([^)]*\)\s*\{(.*?)\n    \}",
            source,
            re.DOTALL,
        )
        self.assertIsNotNone(exited_body, "El handler themeListExited debe existir")
        exited = exited_body.group(1)
        reset = exited.index("themesLoading = false;")
        guard = exited.index("themeListReadOnly")
        self.assertLess(
            reset,
            guard,
            "themeListExited debe limpiar themesLoading antes de cualquier "
            "ramificacion por modo lectura; si no, el modo sin proveedor "
            "se quedaria en themesLoading",
        )

    def test_reload_theme_reloads_all_three_theme_file_views(self) -> None:
        """reloadTheme() debe recargar los tres FileView, incluido overrideView (regresión de D6, tarea 4.3)."""
        theme_source = THEME_QML.read_text(encoding="utf-8")
        body = re.search(r"function\s+reloadTheme\s*\(\)\s*\{(.*?)\n    \}", theme_source, re.DOTALL)
        self.assertIsNotNone(body)
        body_text = body.group(1)
        for view in ("ghosttyView", "waybarView", "overrideView"):
            self.assertIn(f"{view}.reload()", body_text, f"reloadTheme debe recargar {view}")

    def test_parse_ghostty_supports_real_ghostty_palette_form(self) -> None:
        """parseGhostty debe poblar p0..p15 con la forma real `palette = 5=#F5C2E7` (tarea 5.1).

        Contrato estructural: no ejecuta el parser QML; la prueba de runtime es el probe
        aislado (`qs -p /tmp/tsd-probe`). Solo verifica que la estructura del parser
        reconozca el indice del palette a partir del valor, no solo de la clave.
        """
        theme_source = THEME_QML.read_text(encoding="utf-8")
        body = re.search(
            r"function\s+parseGhostty\s*\(\s*txt\s*\)\s*\{(.*?)\n        \}",
            theme_source,
            re.DOTALL,
        )
        self.assertIsNotNone(body, "parseGhostty debe existir en Theme.qml")
        parser = body.group(1)
        # Forma real de ghostty: el primer split en "=" deja key="palette" y
        # val="5=#F5C2E7"; el indice y el color viven en el valor.
        self.assertRegex(
            parser,
            r"val\.match\([^)]*\\d\+[^)]*\)",
            "parseGhostty debe reconocer el indice del palette a partir del valor "
            "(val), no solo de la clave, para la forma `palette = 5=#F5C2E7`",
        )
        self.assertRegex(
            parser,
            r'key\s*===\s*"palette"',
            "El reconocimiento por valor debe acotarse a la clave `palette` para no "
            "alterar ninguna otra clave",
        )
        self.assertRegex(
            parser,
            r'map\["p"\s*\+',
            "El palette detectado debe almacenarse como p0..p15",
        )
        # La forma legada `palette 5 = #RRGGBB` (indice en la clave) se conserva:
        # eliminarla podria romper un bundle no verificado.
        self.assertRegex(
            parser,
            r"key\.match\(\s*/\^palette\\s\+\(\\d\+\)\$/",
            "La forma legada `palette N = #RRGGBB` sobre la clave debe conservarse",
        )

    def test_settings_file_view_uses_shelldir_not_configdir(self) -> None:
        """El FileView de settings lee shell.json desde Quickshell.shellDir (tarea 5.2)."""
        theme_source = THEME_QML.read_text(encoding="utf-8")
        self.assertNotIn(
            "Quickshell.configDir",
            theme_source,
            "Quickshell.configDir esta deprecado en Quickshell 0.3.1 y no debe quedar "
            "en Theme.qml (ni en codigo ni en comentarios)",
        )
        self.assertRegex(
            theme_source,
            r"path:\s*`\$\{Quickshell\.shellDir\}/shell\.json`",
            "El FileView de settings debe seguir leyendo shell.json desde la misma "
            "ubicacion, ahora via Quickshell.shellDir",
        )

    def test_theme_loading_clears_stale_results_and_blocks_acceptance(self) -> None:
        source = LAUNCHER_QML.read_text(encoding="utf-8")
        self.assertRegex(source, r"property\s+bool\s+themesLoading\b")
        load_body = re.search(r"function\s+loadThemes\s*\([^)]*\)\s*\{(.*?)\n\s*\}", source, re.DOTALL)
        self.assertIsNotNone(load_body)
        self.assertRegex(load_body.group(1), r"themes\s*=\s*\[\]")
        self.assertRegex(load_body.group(1), r"results\s*=\s*\[\]")
        self.assertRegex(load_body.group(1), r"themesLoading\s*=\s*true")
        self.assertRegex(source, r"if\s*\(themesLoading\)\s*return")
        self.assertIn("themeLoadGeneration", source)
        self.assertRegex(source, r"if\s*\([^)]*themeLoadGeneration[^)]*\)\s*return")

    def test_readme_documents_cutover_and_rollback(self) -> None:
        source = README.read_text(encoding="utf-8")
        for shortcut in ("SUPER+M", "SUPER+Tab", "SUPER+R", "SUPER+SHIFT+X", "SUPER+SHIFT+T"):
            self.assertIn(shortcut, source)
        self.assertIn("Rollback", source)
        self.assertIn("ipc call selene openApps", source)
        self.assertNotIn("ipc toggleLauncher", source)

    def test_launcher_logic_is_a_pure_registered_service_helper(self) -> None:
        self.assertTrue(LAUNCHER_LOGIC_JS.exists())
        source = LAUNCHER_LOGIC_JS.read_text(encoding="utf-8")
        for function in ("normalizeMode", "cycleMode", "parseCommand", "rankItems"):
            self.assertRegex(source, rf"function\s+{function}\s*\(")

    def test_operation_state_is_a_pure_helper(self) -> None:
        self.assertTrue(OPERATION_STATE_JS.exists())
        source = OPERATION_STATE_JS.read_text(encoding="utf-8")
        for function in ("idle", "begin", "started", "finish", "startupTimeout", "isBusy"):
            self.assertRegex(source, rf"function\s+{function}\s*\(")


if __name__ == "__main__":
    unittest.main(verbosity=2)
