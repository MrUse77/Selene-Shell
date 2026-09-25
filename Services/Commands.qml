pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "./LauncherLogic.js" as LauncherLogic

// Resolución de comandos de herramientas externas (#9).
//
// Cadena exacta por herramienta:
//   1. Variable de entorno neutra  Quickshell.env("<SHELL_*_COMMAND>")
//   2. Setting del shell           Settings.str("<key>")   (shell.json)
//   3. Default actual              comportamiento previo intacto
// Un valor vacío o de tipo equivocado cae al siguiente nivel: nada rompe el clic.
//
// El valor resuelto es un string que se parsea a argv con LauncherLogic.parseCommand
// (quotes y escapes soportados); NUNCA se interpola en `sh -c`. Un quote/escape
// incompleto devuelve ok:false y el fallo se reporta visible, sin ejecutar nada.
Item {
    id: root

    function _resolve(envName, settingKey, fallback) {
        return Theme.pick(Quickshell.env(envName), Settings.str(settingKey), fallback);
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
        return { ok: true, args: parsed.args.concat(extra || []), error: "" };
    }

    // Notificación desktop: el mismo patrón que Launcher/PowerMenu ya usaban.
    function notify(title, message) {
        const parsed = LauncherLogic.parseCommand(notifier);
        if (parsed.ok) {
            Quickshell.execDetached(parsed.args.concat([title, message]));
        } else {
            console.log("[selene:commands] notify no disponible:", parsed.error, "-", title, message);
        }
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
                if (exitCode !== 0)
                    root.notify(proc.title, err.text.trim() || out.text.trim() || ("exit code " + exitCode));
                proc.destroy();
            }
            // FailedToStart (binario ausente) emite runningChanged sin onStarted/onExited.
            onRunningChanged: {
                if (!proc.running && !proc.startedOk) {
                    root.notify(proc.title, "Unable to start " + proc.argv[0]);
                    proc.destroy();
                }
            }
        }
    }
}
