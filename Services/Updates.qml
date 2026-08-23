pragma Singleton

import QtQuick
import Quickshell.Io

// Actualizaciones pendientes (repo + AUR), como el widget de waybar.
// checkupdates toca la red: caché larga + refresh manual (IPC/botón).
Item {
    id: root

    property int count: 0
    property bool checking: false

    readonly property Process checker: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root.checking = false;
                const n = parseInt(this.text.trim());
                root.count = isNaN(n) ? 0 : n;
                console.log("[selene:updates]", root.count, "pendientes");
            }
        }
    }

    function refresh() {
        if (checking) return;
        checking = true;
        checker.exec(["sh", "-c",
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
