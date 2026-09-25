pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "./CommandLogic.js" as CommandLogic
import "./LauncherLogic.js" as LauncherLogic

// Resolución de comandos de herramientas externas (#9).
//
// Cadena exacta por herramienta:
//   1. Variable de entorno neutra  Quickshell.env("<SHELL_*_COMMAND>")
//   2. Setting del shell           Settings.str("<key>")   (shell.json)
//   3. Default actual              comportamiento previo intacto
// La precedencia vive en CommandLogic.resolve (misma semántica documentada para
// Theme.pick): un valor vacío o de tipo equivocado cae al siguiente nivel y nada
// rompe el clic.
//
// Dos semánticas de lanzamiento, explícitas en el nombre (#25, D1):
//   - launch(result, title): TRACKED. El Process es hijo del singleton, reporta
//     started/exited/stderr y muere con el shell. Para comandos cortos donde el
//     código de salida es la única señal real (polkit, consultas de stdout).
//   - launchDetached(result, title, onResult): DETACHED.
//     Quickshell.execDetached desacopla al hijo: sobrevive el reload y no reporta
//     nada. Para lo que dura más que la shell o no debe morir con ella
//     (hyprlock: un reload con la pantalla bloqueada no debe desbloquear).
//
// Por qué existe la sonda: un lanzamiento detached sin binario no tiene
// FailedToStart que reportar, así que quedaría como clic mudo. Antes de spawnear
// se sondea el binario (CommandLogic.probeArgv) y el fallo se reporta visible.
// La sonda es en sí misma un Process tracked de vida útil de milisegundos: si el
// shell recarga dentro de esa ventana, simplemente no se lanza nada.
//
// El fallo del notificador tampoco queda mudo (D4): console.warn más una línea
// acotada en Quickshell.statePath("commands.log").
//
// El valor resuelto es un string que se parsea a argv con LauncherLogic.parseCommand
// (quotes y escapes soportados); NUNCA se interpola en `sh -c`. Un quote/escape
// incompleto devuelve ok:false y el fallo se reporta visible, sin ejecutar nada.
Item {
    id: root

    function _resolve(envName, settingKey, fallback) {
        return CommandLogic.resolve(
            Quickshell.env(envName),
            Settings.str(settingKey),
            fallback
        );
    }

    readonly property string audio: _resolve("SHELL_AUDIO_COMMAND", "audioCommand", "pavucontrol")
    readonly property string updates: _resolve("SHELL_UPDATES_COMMAND", "updatesCommand", "ghostty -e paru")
    readonly property string copy: _resolve("SHELL_COPY_COMMAND", "copyCommand", "wl-copy")
    readonly property string find: _resolve("SHELL_FIND_COMMAND", "findCommand", "find")
    readonly property string lock: _resolve("SHELL_LOCK_COMMAND", "lockCommand", "hyprlock")
    readonly property string hyprctl: _resolve("SHELL_HYPRCTL_COMMAND", "hyprctlCommand", "hyprctl")
    readonly property string systemctl: _resolve("SHELL_SYSTEMCTL_COMMAND", "systemctlCommand", "systemctl")
    readonly property string bluetooth: _resolve("SHELL_BLUETOOTH_COMMAND", "bluetoothCommand", "bluetoothctl")
    readonly property string notifier: _resolve("SHELL_NOTIFY_COMMAND", "notifyCommand", "notify-send -a Selene")

    // Parsea el comando configurado a argv; `extra` se concatena como argumentos
    // propios y no se re-parsea. Quote/escape incompleto devuelve ok:false.
    function argv(command, extra) {
        const parsed = LauncherLogic.parseCommand(command);
        if (!parsed.ok) return parsed;
        return LauncherLogic.okResult(parsed.args.concat(extra || []));
    }

    // Notificación desktop con degradación visible (D4). Se entrega después de
    // que la sonda resuelve, así que es asíncrona: un reload dentro de esa ventana
    // de milisegundos no entrega la notificación, el mismo tradeoff aceptado que
    // launchDetached. Si el notificador no puede correr, el fallo no queda mudo:
    // va a _diagnose.
    function notify(title, message) {
        const parsed = LauncherLogic.parseCommand(notifier);
        if (!parsed.ok) {
            _diagnose(title, message);
            return;
        }
        _probe(parsed.args[0], available => {
            if (!available) {
                _diagnose(title, message);
                return;
            }
            Quickshell.execDetached(parsed.args.concat([title, message]));
        });
    }

    // Fallback del notificador (D4): console.warn deja el mensaje completo en el
    // log de Quickshell y el log acotado lo hace recuperable. La ruta es terminal:
    // nunca vuelve a llamar a notify (evita recursión).
    function _diagnose(title, message) {
        const line = CommandLogic.logLine(new Date().toISOString(), title, message);
        console.warn("[selene:commands]", line);
        _diagBuffer = CommandLogic.appendLog(_diagBuffer, line, CommandLogic.LOG_MAX_LINES);
        _diagLog.setText(_diagBuffer);
    }

    // Contenido ya cargado del log de diagnóstico. Una vez leído se preserva al
    // appender; si el archivo todavía no se leyó, se arranca vacío (degradación
    // aceptada, D4).
    property string _diagBuffer: ""

    FileView {
        id: _diagLog
        path: Quickshell.statePath("commands.log")
        printErrors: false
        onLoaded: root._diagBuffer = text()
        onLoadFailed: root._diagBuffer = ""
        Component.onCompleted: reload()
    }

    // Lanzamiento con degradación visible: parseo inválido, binario ausente o
    // exit != 0 terminan en notify(); ningún fallo queda como clic mudo.
    function launch(result, title) {
        if (!result.ok) {
            notify(title, result.error);
            return;
        }
        const proc = _launcher.createObject(root, { argv: result.args, title: title });
        if (!proc) {
            notify(title, "Unable to create the process");
            return;
        }
        // qmllint disable missing-property
        proc.exec(proc.argv);
        // qmllint enable missing-property
    }

    // Lanzamiento detached (D1): el hijo sobrevive el reload y no reporta nada.
    // La sonda (D3) decide si hay binario antes de spawnear; `onResult` es
    // opcional para los sitios fire-and-forget.
    function launchDetached(result, title, onResult) {
        const done = onResult || function() {};
        if (!result.ok) {
            notify(title, result.error);
            done(false, result.error);
            return;
        }
        _probe(result.args[0], available => {
            if (!available) {
                const message = CommandLogic.failureMessage("start", { program: result.args[0] });
                notify(title, message);
                done(false, message);
                return;
            }
            Quickshell.execDetached(result.args);
            done(true, "");
        });
    }

    // Sonda de ejecutabilidad (D3): exit 0 significa disponible. Un
    // FailedToStart (por ejemplo `sh` ausente) pasa por runningChanged sin
    // onStarted/onExited, igual que un binario no ejecutable. `reported`
    // garantiza una única llamada aunque las señales se solapen.
    function _probe(name, callback) {
        const proc = _probeLauncher.createObject(root, {
            argv: CommandLogic.probeArgv(name),
            probeCallback: callback
        });
        if (!proc) {
            callback(false);
            return;
        }
        // qmllint disable missing-property
        proc.exec(proc.argv);
        // qmllint enable missing-property
    }

    Component {
        id: _launcher
        Process {
            id: proc
            required property var argv
            required property string title
            property bool startedOk: false
            stdout: StdioCollector { id: out }
            stderr: StdioCollector { id: err }
            onStarted: proc.startedOk = true
            onExited: exitCode => {
                const message = CommandLogic.exitMessage(exitCode, err.text, out.text);
                if (message !== "") root.notify(proc.title, message);
                proc.destroy();
            }
            // FailedToStart (binario ausente) emite runningChanged sin onStarted/onExited.
            onRunningChanged: {
                if (CommandLogic.startFailed(proc.startedOk, proc.running)) {
                    root.notify(proc.title, "Unable to start " + proc.argv[0]);
                    proc.destroy();
                }
            }
        }
    }

    Component {
        id: _probeLauncher
        Process {
            id: probeProc
            required property var argv
            required property var probeCallback
            property bool startedOk: false
            property bool reported: false
            stdout: StdioCollector { id: probeOut }
            stderr: StdioCollector { id: probeErr }
            onStarted: probeProc.startedOk = true
            onExited: exitCode => probeProc._report(exitCode === 0)
            // FailedToStart (sh ausente) emite runningChanged sin onStarted/onExited.
            onRunningChanged: {
                if (CommandLogic.startFailed(probeProc.startedOk, probeProc.running))
                    probeProc._report(false);
            }
            function _report(available) {
                if (probeProc.reported) return;
                probeProc.reported = true;
                const callback = probeProc.probeCallback;
                probeProc.destroy();
                if (callback) callback(available);
            }
        }
    }
}
