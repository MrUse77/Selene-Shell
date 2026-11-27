pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "./AppIconLogic.js" as AppIconLogic

// Íconos del launcher resueltos por la shell, no por el tema activo.
//
// El launcher mostraba el ícono del tema porque Quickshell.iconPath termina en
// QIcon::fromTheme, que busca primero el tema configurado en Qt. Esta shell no
// puede reconfigurar ese resolvedor (Quickshell no expone QIcon::setThemeName),
// así que resuelve el archivo por su cuenta: `hicolor` es el tema donde cada
// aplicación instala el ícono que trae por defecto y `pixmaps` es la ubicación
// legacy del estándar. El orden completo vive en AppIconLogic.js y se cubre con
// tests en tests/icon-resolution.
//
// Un único `find` arma el índice al arrancar (~850 archivos, ~10 ms acá) y se
// refresca al abrir el launcher como mucho una vez por minuto, para que una
// app recién instalada o desinstalada se vea sin reiniciar la shell.
//
// El tema queda como último recurso: si la aplicación no publica ícono propio,
// el launcher conserva exactamente el resultado anterior.
Item {
    id: root

    // Mismo fallback que el delegate del launcher usaba antes de este servicio.
    readonly property string fallbackIcon: "application-x-executable"
    readonly property int refreshIntervalMs: 60000

    property var index: AppIconLogic.emptyIndex()
    property bool ready: false
    property bool loading: false
    property double lastRefreshAt: 0

    readonly property var dataDirs: AppIconLogic.dataDirs(
        Quickshell.env("XDG_DATA_DIRS"),
        Quickshell.env("XDG_DATA_HOME"),
        Quickshell.env("HOME")
    )

    // Ruta absoluta del ícono propio de la aplicación o, si no hay, el ícono
    // del tema activo con el mismo fallback de siempre.
    function sourceFor(icon) {
        if (AppIconLogic.isAbsolutePath(icon)) return "file://" + icon.trim();
        const path = AppIconLogic.resolve(icon, root.index);
        if (path !== "") return "file://" + path;
        return Quickshell.iconPath(typeof icon === "string" ? icon : "", root.fallbackIcon);
    }

    function refreshIfStale(intervalMs) {
        if (root.loading) return;
        const interval = (typeof intervalMs === "number" && intervalMs >= 0)
            ? intervalMs
            : root.refreshIntervalMs;
        if (root.lastRefreshAt > 0 && Date.now() - root.lastRefreshAt < interval) return;
        root.refresh();
    }

    function refresh() {
        if (root.loading) return;
        const argv = Commands.argv(Commands.find, AppIconLogic.findArgs(root.dataDirs));
        if (!argv.ok) {
            console.log("[selene:app-icon] find no disponible:", argv.error);
            return;
        }
        const process = indexProcessComponent.createObject(root, { argv: argv.args });
        if (!process) {
            console.log("[selene:app-icon] no se pudo crear el proceso del índice");
            return;
        }
        root.loading = true;
        // qmllint disable missing-property
        process.exec(argv.args);
        // qmllint enable missing-property
    }

    Component.onCompleted: root.refresh()

    Component {
        id: indexProcessComponent

        Process {
            id: process
            required property var argv
            property bool startedOk: false

            stdout: StdioCollector { id: out }
            stderr: StdioCollector { id: err }

            onStarted: {
                process.startedOk = true;
                root.lastRefreshAt = Date.now();
            }

            onExited: exitCode => {
                root.loading = false;
                // `find` sale != 0 si alguna raíz no existe (pixmaps de un
                // XDG_DATA_DIR opcional, por ejemplo); stdout sigue siendo
                // válido y el índice se arma igual con lo encontrado.
                if (out.text.trim() !== "") {
                    root.index = AppIconLogic.parseIndex(out.text);
                    root.ready = true;
                } else if (exitCode !== 0) {
                    console.log("[selene:app-icon] índice vacío:",
                        err.text.trim() || ("exit code " + exitCode));
                }
                process.destroy();
            }

            // FailedToStart (binario ausente) emite runningChanged sin
            // onStarted/onExited: se libera el proceso y queda el fallback.
            onRunningChanged: {
                if (!process.running && !process.startedOk) {
                    root.loading = false;
                    console.log("[selene:app-icon] no se pudo iniciar", process.argv[0]);
                    process.destroy();
                }
            }
        }
    }
}
