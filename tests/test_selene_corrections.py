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


class SeleneCorrectionContracts(unittest.TestCase):
    def test_moon_has_no_qmllint_unqualified_access(self) -> None:
        result = subprocess.run(
            [
                "qmllint",
                "-U",
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


if __name__ == "__main__":
    unittest.main(verbosity=2)
