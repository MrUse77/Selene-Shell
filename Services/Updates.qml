pragma Singleton

import QtQuick
import Quickshell.Io

// Actualizaciones pendientes (repo + AUR), como el widget de waybar.
// checkupdates toca la red: caché larga + refresh manual (IPC/botón).
// Si no existen `checkupdates` ni `paru`, no se puede chequear: el comando
// emite el marcador negativo -1 y `unavailable` queda en true. `count`
// conserva su semántica para el consumidor actual (el widget sigue visible
// solo con count > 0), pero "no pude chequear" ya no es indistinguible de
// "estás al día".
Item {
    id: root

    property int count: 0
    property bool unavailable: false
    property bool checking: false

    readonly property Process checker: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root.checking = false;
                const n = parseInt(this.text.trim());
                root.unavailable = n === -1;
                root.count = isNaN(n) ? 0 : n;
                console.log("[selene:updates]", root.count, "pendientes");
            }
        }
    }

    function refresh() {
        if (checking) return;
        checking = true;
        checker.exec(["sh", "-c",
            // -1: ni `checkupdates` ni `paru` existen; no se puede chequear.
            "command -v checkupdates >/dev/null 2>&1 || command -v paru >/dev/null 2>&1 || { echo -1; exit 0; }; " +
            "{ checkupdates; paru -Qua 2>/dev/null; } | sort -u | grep -c . || true"]);
    }

    Timer {
        interval: 30 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
