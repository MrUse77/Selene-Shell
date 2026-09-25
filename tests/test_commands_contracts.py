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
COMMAND_LOGIC_JS = PROJECT_ROOT / "Services" / "CommandLogic.js"
SERVICES_QMLDIR = PROJECT_ROOT / "Services" / "qmldir"
SHELL_JSON = PROJECT_ROOT / "shell.json"
MODULES_DIR = PROJECT_ROOT / "Modules"
LAUNCHER_QML = MODULES_DIR / "Launcher" / "Launcher.qml"
POWER_MENU_QML = MODULES_DIR / "PowerMenu" / "PowerMenu.qml"
DASHBOARD_QML = MODULES_DIR / "Dashboard" / "Dashboard.qml"
LAUNCHER_LOGIC_JS = PROJECT_ROOT / "Services" / "LauncherLogic.js"
COMMANDS_SUITE_QML = PROJECT_ROOT / "tests" / "commands" / "tst_commands_logic.qml"

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
            r"CommandLogic\.resolve\(\s*Quickshell\.env\(envName\),\s*"
            r"Settings\.str\(settingKey\),\s*fallback\s*\)",
            "_resolve must delegate env first, then setting, then default",
        )

    def test_command_logic_stays_pure_and_declares_pragma_library(self) -> None:
        self.assertTrue(COMMAND_LOGIC_JS.exists(), "Services/CommandLogic.js must exist")
        source = self.read(COMMAND_LOGIC_JS)
        self.assertIn(".pragma library", source)
        self.assertNotRegex(
            source,
            re.compile(r"^\s*import\b", re.MULTILINE),
            "CommandLogic.js must stay free of Qt/Quickshell imports",
        )
        for symbol in (
            "function resolve(",
            "function probeArgv(",
            "function failureMessage(",
            "function startFailed(",
            "function logLine(",
            "function appendLog(",
        ):
            self.assertIn(symbol, source, f"CommandLogic.js must expose {symbol}")
        self.assertRegex(source, r"const\s+LOG_MAX_LINES\s*=\s*50\b")

    def test_notify_probes_the_notifier_before_delivering(self) -> None:
        source = self.read(COMMANDS_QML)
        body = re.search(r"function\s+notify\([\s\S]*?\n    \}", source)
        self.assertIsNotNone(body, "Commands.notify must exist")
        block = body.group(0)
        self.assertIn("_probe(", block)
        self.assertIn("Quickshell.execDetached(", block)
        self.assertLess(
            block.index("_probe("),
            block.index("Quickshell.execDetached("),
            "notify must probe the notifier before delivering",
        )
        self.assertIn("_diagnose(", block)

    def test_notify_failure_is_diagnosed_with_warn_and_bounded_log(self) -> None:
        source = self.read(COMMANDS_QML)
        diagnose = re.search(r"function\s+_diagnose\([\s\S]*?\n    \}", source)
        self.assertIsNotNone(diagnose, "Commands must declare the _diagnose fallback")
        block = diagnose.group(0)
        self.assertIn("console.warn", block)
        self.assertIn("CommandLogic.appendLog(", block)
        self.assertIn("CommandLogic.LOG_MAX_LINES", block)
        # La ruta de diagnóstico es terminal: no puede volver a notify.
        self.assertNotIn("notify(", block)
        # Log acotado en el state dir, sin ruido de errores si falta el archivo.
        self.assertIn('Quickshell.statePath("commands.log")', source)
        self.assertIn("FileView", source)
        self.assertIn("printErrors: false", source)
        self.assertIn("onLoadFailed", source)

    def test_dashboard_bluetooth_poll_surfaces_the_unavailable_state(self) -> None:
        source = self.read(DASHBOARD_QML)
        refresh = re.search(r"function\s+refreshBt\([\s\S]*?\n    \}", source)
        self.assertIsNotNone(refresh, "Dashboard.refreshBt must exist")
        block = refresh.group(0)
        self.assertIn(
            "btUnavailable = true",
            block,
            "a non-parsing poll must surface the unavailable state, not a mute skip",
        )
        # El fallo del proceso del sondeo también cuenta (FailedToStart).
        self.assertIn("startedOk", source)
        self.assertIn("btUnavailable = true", source)
        # Una salida no reconocida (exit 0 sin "Powered:") tampoco se lee como
        # verdad: el sondeo se declara no disponible en vez de repetir el valor
        # viejo, y la conclusión se difiere un turno para no pisar la última
        # lectura pendiente del pipe.
        self.assertIn("sawPowered", source)
        exited = re.search(r"onExited:[\s\S]*?\n        \}", source)
        self.assertIsNotNone(exited, "the poll must handle its exit code")
        self.assertIn("sawPowered", exited.group(0))
        self.assertIn("Qt.callLater", exited.group(0))
        # La tarjeta muestra el estado no disponible en vez del valor viejo.
        self.assertIn("Bluetooth unavailable", source)

    def test_launch_detached_uses_exec_detached(self) -> None:
        source = self.read(COMMANDS_QML)
        body = re.search(r"function\s+launchDetached\([\s\S]*?\n    \}", source)
        self.assertIsNotNone(body, "Commands.launchDetached must exist")
        self.assertIn("Quickshell.execDetached(result.args)", body.group(0))

    def test_launch_detached_probes_before_spawning(self) -> None:
        source = self.read(COMMANDS_QML)
        body = re.search(r"function\s+launchDetached\([\s\S]*?\n    \}", source)
        self.assertIsNotNone(body, "Commands.launchDetached must exist")
        block = body.group(0)
        self.assertIn('CommandLogic.failureMessage("start"', block)
        self.assertIn("_probe(", block)
        self.assertLess(
            block.index("_probe("),
            block.index("Quickshell.execDetached("),
            "launchDetached must probe the binary before spawning",
        )
        # La sonda usa el argv exacto de CommandLogic (nombre como parámetro).
        probe_helper = re.search(r"function\s+_probe\([\s\S]*?\n    \}", source)
        self.assertIsNotNone(probe_helper, "Commands must declare the probe helper")
        self.assertIn("CommandLogic.probeArgv(name)", probe_helper.group(0))

    def test_detached_call_sites_never_track_a_process(self) -> None:
        tracked = re.compile(
            r"Commands\.launch\(\s*Commands\.argv\(\s*"
            r"Commands\.(?:audio|updates|copy|lock)\b"
        )
        for path in sorted(MODULES_DIR.rglob("*.qml")):
            self.assertIsNone(
                tracked.search(path.read_text(encoding="utf-8")),
                f"{path.relative_to(PROJECT_ROOT)} must not track a detached command",
            )
        # AudioWidget ya no lanza nada: el clic abre el selector de dispositivo
        # (Modules/Bar/AudioPickerPopup.qml), asi que no entra en este contrato.
        for rel in ("Bar/UpdatesWidget.qml",):
            source = self.read(MODULES_DIR / rel)
            self.assertIn("Commands.launchDetached", source)
            self.assertNotIn(
                "Process {",
                source,
                f"{rel} must not declare its own tracked Process",
            )
        power = self.read(POWER_MENU_QML)
        lock_branch = re.search(r"action\.tool === \"lock\"[\s\S]*?\n        \}", power)
        self.assertIsNotNone(lock_branch, "PowerMenu must split the hyprlock branch")
        self.assertIn("Commands.launchDetached", lock_branch.group(0))
        self.assertNotIn("createObject", lock_branch.group(0))

    def test_tracked_exit_handler_delegates_to_command_logic(self) -> None:
        source = self.read(COMMANDS_QML)
        handler = re.search(r"onExited:\s*exitCode\s*=>\s*\{[\s\S]*?\n            \}", source)
        self.assertIsNotNone(handler, "Commands must keep the tracked exit handler")
        block = handler.group(0)
        self.assertIn("CommandLogic.exitMessage(exitCode, err.text, out.text)", block)
        self.assertIn("proc.destroy()", block)
        # La decisión inline ya no vive acá: ahora es ejecutable desde el test.
        self.assertNotIn("err.text.trim() || out.text.trim()", block)
        self.assertNotIn('"exit code "', block)

    def test_success_record_has_a_single_producer(self) -> None:
        logic = self.read(LAUNCHER_LOGIC_JS)
        commands = self.read(COMMANDS_QML)
        launcher = self.read(LAUNCHER_QML)
        self.assertIn("function okResult(args)", logic)
        self.assertIn("return okResult(args);", logic)
        self.assertIn("LauncherLogic.okResult(parsed.args.concat(extra || []))", commands)
        self.assertIn("LauncherLogic.okResult([])", launcher)
        # El camino de fallo sigue devolviendo el record del parser tal cual.
        self.assertIn("if (!parsed.ok) return parsed;", commands)
        rebuilt = re.compile(r"\{\s*ok:\s*true,\s*args:")
        offenders = [
            str(path.relative_to(PROJECT_ROOT))
            for path in sorted(MODULES_DIR.rglob("*.qml"))
            if rebuilt.search(path.read_text(encoding="utf-8"))
        ]
        self.assertEqual(
            offenders,
            [],
            f"success record rebuilt by hand instead of LauncherLogic.okResult: {offenders}",
        )

    def test_qml_suite_covers_the_failure_paths_by_name(self) -> None:
        source = self.read(COMMANDS_SUITE_QML)
        self.assertIn(
            'import "../../Services/LauncherLogic.js" as LauncherLogic',
            source,
            "the suite must cross-check the parser that produces the parse error",
        )
        for case in (
            "test_parse_failure_message_comes_from_the_parser",
            "test_start_failure_message_names_the_program",
            "test_start_failed_truth_table",
            "test_exit_message_precedence",
            "test_exit_message_is_empty_on_success",
            "test_ok_result_matches_the_parser_success_shape",
        ):
            self.assertIn(f"function {case}(", source, f"the QML suite must cover {case}")

    def test_start_failure_rule_is_shared_not_inline(self) -> None:
        source = self.read(COMMANDS_QML)
        self.assertIn("CommandLogic.startFailed(proc.startedOk, proc.running)", source)
        self.assertIn(
            "CommandLogic.startFailed(probeProc.startedOk, probeProc.running)",
            source,
        )
        self.assertEqual(
            source.count("CommandLogic.startFailed("),
            2,
            "both runningChanged handlers must share the single startFailed rule",
        )
        # Las comparaciones inline duplicadas no pueden volver.
        self.assertNotIn("!proc.running && !proc.startedOk", source)
        self.assertNotIn("!probeProc.running && !probeProc.startedOk", source)

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
            "Bar/UpdatesWidget.qml": ("Commands.updates", "Commands.launchDetached"),
            "Launcher/Launcher.qml": (
                "Commands.copy",
                "Commands.find",
                "Commands.notify",
                "Commands.launchDetached",
            ),
            "PowerMenu/PowerMenu.qml": (
                "Commands.lock",
                "Commands.systemctl",
                "Commands.hyprctl",
                "Commands.notify",
                "Commands.launch",
                "Commands.launchDetached",
            ),
            "Dashboard/Dashboard.qml": (
                "Commands.bluetooth",
                "Commands.systemctl",
                "Commands.lock",
                "Commands.hyprctl",
                "Commands.launch",
                "Commands.launchDetached",
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
        # El volumen ya no lanza un comando externo: abre el selector de
        # dispositivo propio (Modules/Bar/AudioPickerPopup.qml).
        for rel in (
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
