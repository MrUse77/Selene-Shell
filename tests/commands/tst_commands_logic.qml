import QtQuick
import QtTest
import "../../Services/CommandLogic.js" as CommandLogic

// Tests deterministas de la lógica pura de comandos externos (#25, D6).
// El módulo bajo prueba no importa Qt ni Quickshell, así que cubre precedencia,
// argv de la sonda y los mensajes de fallo sin levantar la shell.
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
}
