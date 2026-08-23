pragma Singleton

import QtQuick
import Quickshell.Io

// Métricas del sistema. /proc reporta tamaño 0, así que los watchers de
// FileView no sirven: re-lectura por Timer. `active` permite pausar el
// muestreo cuando nadie mira (lo bindea el dashboard).
Item {
    id: root

    property bool active: true

    property real cpu: 0        // 0..100
    property real ram: 0        // 0..100
    property real temp: 0       // °C
    property real disk: 0       // 0..100
    property real uptimeSec: 0

    readonly property real cpuWarn: 70
    readonly property real cpuCrit: 90
    readonly property real ramWarn: 80
    readonly property real tempWarn: 80

    // ---- CPU: delta entre muestras de /proc/stat ----
    property var _prevCpu: null

    FileView {
        id: statView
        path: "/proc/stat"
        watchChanges: false
        printErrors: false
        onLoaded: {
            const line = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            if (line.length < 5) return;
            // user nice system idle iowait irq softirq steal
            const idle = line[3] + line[4];
            const total = line.reduce((a, b) => a + b, 0);
            if (root._prevCpu) {
                const dTotal = total - root._prevCpu.total;
                const dIdle = idle - root._prevCpu.idle;
                if (dTotal > 0)
                    root.cpu = Math.round((1 - dIdle / dTotal) * 100);
            }
            root._prevCpu = { total: total, idle: idle };
        }
    }

    FileView {
        id: memView
        path: "/proc/meminfo"
        watchChanges: false
        printErrors: false
        onLoaded: {
            const info = {};
            for (const line of text().split("\n")) {
                const m = line.match(/^(\w+):\s+(\d+)/);
                if (m) info[m[1]] = Number(m[2]);
            }
            if (info.MemTotal > 0)
                root.ram = Math.round((1 - (info.MemAvailable ?? 0) / info.MemTotal) * 100);
        }
    }

    FileView {
        id: uptimeView
        path: "/proc/uptime"
        watchChanges: false
        printErrors: false
        onLoaded: {
            const s = parseFloat(text().split(" ")[0]);
            if (!isNaN(s)) root.uptimeSec = s;
        }
    }

    // ---- Temperatura: primer hwmon (k10temp Tctl en este equipo) ----
    property Process tempProc: Process {
        stdout: SplitParser {
            onRead: data => {
                const v = parseFloat(data);
                if (!isNaN(v)) root.temp = Math.round(v / 1000);
            }
        }
    }

    // ---- Disco: porcentaje usado de / ----
    property Process diskProc: Process {
        stdout: SplitParser {
            onRead: data => {
                const m = data.match(/(\d+)%/);
                if (m) root.disk = Number(m[1]);
            }
        }
    }

    function refreshProcs() {
        tempProc.exec(["sh", "-c",
            "cat /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | head -n1"]);
        diskProc.exec(["df", "--output=pcent", "/"]);
    }

    Timer {
        interval: 2000
        running: root.active
        repeat: true
        onTriggered: {
            statView.reload();
            memView.reload();
            uptimeView.reload();
        }
    }

    Timer {
        interval: 5000
        running: root.active
        repeat: true
        onTriggered: root.refreshProcs()
    }

    Component.onCompleted: {
        statView.reload();
        memView.reload();
        uptimeView.reload();
        refreshProcs();
    }

    function uptimeText() {
        const s = Math.floor(uptimeSec);
        const d = Math.floor(s / 86400);
        const h = Math.floor((s % 86400) / 3600);
        const m = Math.floor((s % 3600) / 60);
        if (d > 0) return `${d} d ${h} h`;
        if (h > 0) return `${h} h ${m} min`;
        return `${m} min`;
    }
}
