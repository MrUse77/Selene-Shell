import QtQuick
import QtTest
import "../../Services/CommandLogic.js" as CommandLogic
import "../../Services/LauncherLogic.js" as LauncherLogic

// Tests deterministas de la lógica pura de comandos externos (#25/#27, D6).
// El módulo bajo prueba no importa Qt ni Quickshell, así que cubre precedencia,
// argv de la sonda, shape del record y los caminos de fallo sin levantar la shell.
// Se ejecutan con: QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/commands/tst_commands_logic.qml
TestCase {
    id: root
    name: "CommandsLogic"

    // El nombre viaja siempre como parámetro posicional; el script es constante.
    readonly property string probeScript: 'command -v -- "$1" >/dev/null 2>&1'

    function test_resolve_prefers_env_then_setting_then_default() {
        compare(
            CommandLogic.resolve("/usr/bin/pavucontrol", "pavucontrol", "fallback"),
            "/usr/bin/pavucontrol"
        );
        compare(
            CommandLogic.resolve("", "pavucontrol", "fallback"),
            "pavucontrol"
        );
        compare(
            CommandLogic.resolve("", "", "fallback"),
            "fallback"
        );
    }

    // Misma semántica documentada para Theme.pick: un nivel vacío, ausente o de
    // tipo equivocado cae al siguiente; el default nunca es un string vacío
    // impuesto por accidente.
    function test_empty_and_non_string_values_fall_through() {
        compare(CommandLogic.resolve("", "hyprlock", "fallback"), "hyprlock");
        compare(CommandLogic.resolve(undefined, "hyprlock", "fallback"), "hyprlock");
        compare(CommandLogic.resolve(null, "hyprlock", "fallback"), "hyprlock");
        compare(CommandLogic.resolve(42, "hyprlock", "fallback"), "hyprlock");
        compare(CommandLogic.resolve(false, "hyprlock", "fallback"), "hyprlock");
        compare(CommandLogic.resolve({}, "hyprlock", "fallback"), "hyprlock");
        compare(CommandLogic.resolve([], "hyprlock", "fallback"), "hyprlock");
        compare(
            CommandLogic.resolve(42, { nested: true }, "fallback"),
            "fallback"
        );
    }

    function test_resolve_returns_the_fallback_verbatim() {
        compare(CommandLogic.resolve("", "", "ghostty -e paru"), "ghostty -e paru");
        compare(CommandLogic.resolve(undefined, undefined, "notify-send -a Selene"),
                "notify-send -a Selene");
    }

    function test_probe_argv_is_exact_for_a_plain_name() {
        const argv = CommandLogic.probeArgv("pavucontrol");
        compare(argv.length, 5);
        compare(argv[0], "sh");
        compare(argv[1], "-c");
        compare(argv[2], root.probeScript);
        compare(argv[3], "selene-command-probe");
        compare(argv[4], "pavucontrol");
    }

    // Invariante dura (#9/D3): el nombre NUNCA se interpola en la cadena del
    // -c. Aunque traiga espacios y metacaracteres de shell, el script queda
    // byte a byte igual y el nombre sólo es alcanzable como $1 / args[4].
    function test_probe_keeps_shell_metacharacters_out_of_the_script() {
        const name = "$(touch /tmp/pwned); `reboot` \"double\" 'single' | cat";
        const argv = CommandLogic.probeArgv(name);
        compare(argv.length, 5);
        compare(argv[0], "sh");
        compare(argv[1], "-c");
        compare(argv[2], root.probeScript);
        compare(argv[3], "selene-command-probe");
        compare(argv[4], name);
        verify(
            argv[2].indexOf(name) === -1,
            "el script de la sonda no debe contener el nombre"
        );
        verify(
            argv[2].indexOf("$(") === -1 && argv[2].indexOf("$(touch") === -1,
            "el script de la sonda no debe contener substitución de comandos"
        );
        for (let i = 0; i < 4; i++) {
            verify(
                argv[i].indexOf(name) === -1,
                "el nombre sólo debe ser alcanzable en args[4], no en args[" + i + "]"
            );
        }
    }

    function test_probe_argv_does_not_mutate_the_name() {
        const name = "  spaced name  ";
        compare(CommandLogic.probeArgv(name)[4], name);
    }

    // Los tres mensajes visibles quedan byte a byte como los emitía
    // Services/Commands.qml antes de #25.
    function test_failure_message_table() {
        compare(
            CommandLogic.failureMessage("parse", { error: "Unterminated quote" }),
            "Unterminated quote"
        );
        compare(
            CommandLogic.failureMessage("create", {}),
            "Unable to create the process"
        );
        compare(
            CommandLogic.failureMessage("start", { program: "hyprlock" }),
            "Unable to start hyprlock"
        );
    }

    // --- Log de diagnóstico acotado (D4) ---

    function test_log_max_lines_is_the_documented_bound() {
        compare(CommandLogic.LOG_MAX_LINES, 50);
    }

    // El mensaje realista es el stderr multilínea de una herramienta: el
    // formato debe colapsarlo a un único renglón.
    function test_log_line_flattens_a_multiline_message() {
        const line = CommandLogic.logLine(
            "2024-01-01T00:00:00Z",
            "Selene command failed",
            "line one\nline two\r\nline three"
        );
        compare(line, "[2024-01-01T00:00:00Z] Selene command failed — line one line two line three");
        compare(line.split("\n").length, 1);
        compare(line.indexOf("\r"), -1);
        verify(line.indexOf("2024-01-01T00:00:00Z") !== -1, "la línea debe incluir el stamp");
        verify(line.indexOf("Selene command failed") !== -1, "la línea debe incluir el título");
        verify(line.indexOf("line three") !== -1, "la línea debe incluir el mensaje");
    }

    function test_log_line_trims_surrounding_whitespace() {
        compare(CommandLogic.logLine("S", "T", "boom\n"), "[S] T — boom");
        compare(CommandLogic.logLine("S", "T", "boom \n"), "[S] T — boom");
        compare(CommandLogic.logLine("S", "T", "\n\n"), "[S] T —");
    }

    function test_append_log_handles_empty_and_missing_trailing_newline() {
        compare(CommandLogic.appendLog("", "one", 50), "one\n");
        compare(CommandLogic.appendLog("one", "two", 50), "one\ntwo\n");
        compare(CommandLogic.appendLog("one\n", "two", 50), "one\ntwo\n");
    }

    function test_append_log_keeps_exactly_max_lines() {
        compare(CommandLogic.appendLog("a\nb\n", "c", 3), "a\nb\nc\n");
        verify(CommandLogic.appendLog("a\n", "b", 1).endsWith("\n"));
    }

    // El log es una superficie acotada: las líneas más viejas se descartan.
    function test_append_log_drops_the_oldest_beyond_the_bound() {
        compare(CommandLogic.appendLog("a\nb\nc\n", "d", 3), "b\nc\nd\n");
        compare(CommandLogic.appendLog("a\nb\nc\n", "d", 2), "c\nd\n");
        compare(CommandLogic.appendLog("a\n\n\nb\n", "c", 5), "a\nb\nc\n");
    }

    // --- Caminos de fallo ejecutables (issue #27) ---

    // parse: el mensaje visible es el error del propio parser, no una copia.
    function test_parse_failure_message_comes_from_the_parser() {
        const unterminated = LauncherLogic.parseCommand("ghostty -e 'paru");
        compare(unterminated.ok, false);
        compare(
            CommandLogic.failureMessage("parse", { error: unterminated.error }),
            unterminated.error
        );

        const trailing = LauncherLogic.parseCommand("ghostty -e paru\\");
        compare(trailing.ok, false);
        compare(
            CommandLogic.failureMessage("parse", { error: trailing.error }),
            trailing.error
        );
    }

    // start (FailedToStart): el binario no arrancó, no hay stderr que leer.
    function test_start_failure_message_names_the_program() {
        compare(
            CommandLogic.failureMessage("start", { program: "pavucontrol" }),
            "Unable to start pavucontrol"
        );
    }

    // Regla compartida de FailedToStart: `runningChanged` con running === false
    // sin `started` ni `exited` es el único caso de fallo de arranque.
    function test_start_failed_truth_table() {
        // nunca arrancó y no corre: es un fallo de arranque
        compare(CommandLogic.startFailed(false, false), true);
        // arrancó y ya no corre: es una salida normal, no un fallo de arranque
        compare(CommandLogic.startFailed(true, false), false);
        // corre sin haber emitido started todavía: no es fallo
        compare(CommandLogic.startFailed(false, true), false);
        // arrancó y sigue corriendo: no es fallo
        compare(CommandLogic.startFailed(true, true), false);
    }

    // exit: precedencia del mensaje de salida.
    function test_exit_message_precedence() {
        compare(CommandLogic.exitMessage(1, "stderr text", "stdout text"), "stderr text");
        compare(CommandLogic.exitMessage(1, "", "stdout text"), "stdout text");
        compare(CommandLogic.exitMessage(1, "  \n", "\tstdout text " ), "stdout text");
        compare(CommandLogic.exitMessage(1, "  ", "\n"), "exit code 1");
        compare(CommandLogic.exitMessage(2, "", ""), "exit code 2");
        compare(CommandLogic.exitMessage(3), "exit code 3");
    }

    // Un exit 0 no es un fallo ni siquiera con texto en los streams.
    function test_exit_message_is_empty_on_success() {
        compare(CommandLogic.exitMessage(0, "stderr text", "stdout text"), "");
        compare(CommandLogic.exitMessage(0, "", ""), "");
    }

    // shape: okResult es el único productor del éxito que hoy reconstruía a
    // mano el selector de temas.
    function test_ok_result_matches_the_parser_success_shape() {
        const parsed = LauncherLogic.parseCommand("hyprlock --version");
        const built = LauncherLogic.okResult(parsed.args);
        compare(parsed.ok, true);
        compare(built.ok, parsed.ok);
        compare(built.error, parsed.error);
        compare(built.args.length, parsed.args.length);
        for (let i = 0; i < parsed.args.length; i++)
            compare(built.args[i], parsed.args[i]);
    }

    function test_ok_result_exposes_an_empty_args_array() {
        const empty = LauncherLogic.okResult([]);
        compare(empty.ok, true);
        compare(empty.error, "");
        compare(empty.args.length, 0);
    }

    // Los argumentos extra se concatenan tal cual: un valor con quotes o
    // espacios sigue siendo un único argumento y no se re-parsea.
    function test_extra_arguments_are_appended_without_reparsing() {
        const parsed = LauncherLogic.parseCommand("wl-copy");
        const extra = ["two words", 'a "quoted" value', "$HOME; reboot"];
        const result = LauncherLogic.okResult(parsed.args.concat(extra));
        compare(result.ok, true);
        compare(result.args.length, 4);
        compare(result.args[0], "wl-copy");
        compare(result.args[1], "two words");
        compare(result.args[2], 'a "quoted" value');
        compare(result.args[3], "$HOME; reboot");
    }
}
