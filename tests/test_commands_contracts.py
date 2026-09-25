#!/usr/bin/env python3
"""Structural contracts for configurable external tool commands (issue #9).

No module may invoke a fixed tool name: every configured command resolves
env -> shell.json -> current default, parses to argv without a shell, and
degrades visibly (inline status surfaces or the desktop-notification pattern).
"""

from pathlib import Path
import json
import re
import unittest


PROJECT_ROOT = Path(__file__).resolve().parents[1]
COMMANDS_QML = PROJECT_ROOT / "Services" / "Commands.qml"
SERVICES_QMLDIR = PROJECT_ROOT / "Services" / "qmldir"
SHELL_JSON = PROJECT_ROOT / "shell.json"
MODULES_DIR = PROJECT_ROOT / "Modules"
LAUNCHER_QML = MODULES_DIR / "Launcher" / "Launcher.qml"
POWER_MENU_QML = MODULES_DIR / "PowerMenu" / "PowerMenu.qml"

# env name, shell.json key, default — the full resolution chain per command.
CHAINS = {
    "audio": ("SHELL_AUDIO_COMMAND", "audioCommand", "pavucontrol"),
    "updates": ("SHELL_UPDATES_COMMAND", "updatesCommand", "ghostty -e paru"),
    "copy": ("SHELL_COPY_COMMAND", "copyCommand", "wl-copy"),
    "find": ("SHELL_FIND_COMMAND", "findCommand", "find"),
    "lock": ("SHELL_LOCK_COMMAND", "lockCommand", "hyprlock"),
    "hyprctl": ("SHELL_HYPRCTL_COMMAND", "hyprctlCommand", "hyprctl"),
    "systemctl": ("SHELL_SYSTEMCTL_COMMAND", "systemctlCommand", "systemctl"),
    "bluetooth": ("SHELL_BLUETOOTH_COMMAND", "bluetoothCommand", "bluetoothctl"),
    "notifier": ("SHELL_NOTIFY_COMMAND", "notifyCommand", "notify-send -a Selene"),
}
FORBIDDEN = (
    "find|pavucontrol|ghostty|wl-copy|hyprlock|systemctl|hyprctl|"
    "bluetoothctl|notify-send"
)


class ToolCommandContracts(unittest.TestCase):
    def read(self, path: Path) -> str:
        return path.read_text(encoding="utf-8")

    def test_commands_singleton_declares_every_full_chain(self) -> None:
        source = self.read(COMMANDS_QML)
        self.assertIn("pragma Singleton", source)
        self.assertIn(
            "singleton Commands Commands.qml",
            self.read(SERVICES_QMLDIR),
        )
        for name, (env, key, default) in CHAINS.items():
            self.assertIn(
                f'_resolve("{env}", "{key}", "{default}")',
                source,
                f"{name} must declare env -> setting -> default",
            )

    def test_resolve_delegates_env_before_settings_before_default(self) -> None:
        source = self.read(COMMANDS_QML)
        self.assertRegex(
            source,
            r"Theme\.pick\(\s*Quickshell\.env\(envName\),\s*"
            r"Settings\.str\(settingKey\),\s*fallback\s*\)",
            "_resolve must delegate with env first, then setting, then default",
        )

    def test_shell_json_declares_every_new_key_as_null(self) -> None:
        values = json.loads(self.read(SHELL_JSON))
        for name, (env, key, default) in CHAINS.items():
            self.assertIn(key, values, f"shell.json must declare {key}")
            self.assertIsNone(
                values[key],
                f"{key} must be null (use the default) or a configured string",
            )

    def test_configured_commands_parse_to_argv_without_a_shell(self) -> None:
        source = self.read(COMMANDS_QML)
        self.assertIn("LauncherLogic.parseCommand(command)", source)
        self.assertNotIn('"sh"', source)
        self.assertNotRegex(source, r'"-c"')

    def test_no_module_uses_forbidden_tool_literals(self) -> None:
        pattern = re.compile(rf'[\[{{,]\s*"({FORBIDDEN})"')
        offenders = []
        for path in sorted(MODULES_DIR.rglob("*.qml")):
            if pattern.search(path.read_text(encoding="utf-8")):
                offenders.append(str(path.relative_to(PROJECT_ROOT)))
        self.assertEqual(
            offenders,
            [],
            f"fixed tool literals without Commands resolution: {offenders}",
        )

    def test_migrated_modules_route_through_commands(self) -> None:
        expectations = {
            "Bar/AudioWidget.qml": ("Commands.audio", "Commands.launch"),
            "Bar/UpdatesWidget.qml": ("Commands.updates", "Commands.launch"),
            "Launcher/Launcher.qml": (
                "Commands.copy",
                "Commands.find",
                "Commands.notify",
            ),
            "PowerMenu/PowerMenu.qml": (
                "Commands.lock",
                "Commands.systemctl",
                "Commands.hyprctl",
                "Commands.notify",
            ),
            "Dashboard/Dashboard.qml": (
                "Commands.bluetooth",
                "Commands.systemctl",
                "Commands.lock",
                "Commands.hyprctl",
                "Commands.launch",
            ),
        }
        for rel, tokens in expectations.items():
            source = self.read(MODULES_DIR / rel)
            for token in tokens:
                self.assertIn(token, source, f"{rel} must use {token}")

    def test_visible_degradation_uses_existing_surfaces(self) -> None:
        launcher = self.read(LAUNCHER_QML)
        power = self.read(POWER_MENU_QML)
        self.assertIn("statusError = true;", launcher)
        self.assertIn("statusText = copied.error;", launcher)
        self.assertIn("statusText = findArgv.error;", launcher)
        self.assertIn("errorText = argv.error;", power)
        # Widgets without inline status notify through the shared launcher.
        for rel in (
            "Bar/AudioWidget.qml",
            "Bar/UpdatesWidget.qml",
            "Dashboard/Dashboard.qml",
        ):
            self.assertIn(
                "Commands.launch",
                self.read(MODULES_DIR / rel),
                f"{rel} must surface failures via Commands.launch",
            )
        # Commands.launch itself monitors parse/start/exit failures.
        commands = self.read(COMMANDS_QML)
        self.assertIn("onExited", commands)
        self.assertIn("onRunningChanged", commands)
        self.assertIn("root.notify(", commands)

    def test_run_mode_and_theme_selector_stay_unmigrated(self) -> None:
        launcher = self.read(LAUNCHER_QML)
        self.assertIn("LauncherLogic.parseCommand(searchInput.text)", launcher)
        self.assertIn("Theme.pick(", launcher)
        self.assertIn('Quickshell.env("SHELL_THEME_COMMAND")', launcher)


if __name__ == "__main__":
    unittest.main(verbosity=2)
