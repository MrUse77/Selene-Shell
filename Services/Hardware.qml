pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Métricas del sistema. /proc reporta tamaño 0, así que los watchers de
// FileView no sirven: re-lectura por Timer. `active` permite pausar el
// muestreo cuando nadie mira (lo bindea el dashboard).
Item {
    id: root

    property bool active: true

    property real cpu: 0        // 0..100
    property real ram: 0        // 0..100
    // ---- Temperatura ----
    // Sensor resoluble por cadena: SHELL_TEMP_SENSOR (env neutra) →
    // shell.json.tempSensor (Theme.settingsTempSensor) → autodetección por
    // `name` del hwmon (k10temp/coretemp/zenpower/cpu_thermal) → primer
    // hwmon (último recurso, comportamiento actual).
    // El valor configurado acepta tres formas (si no matchea el patrón
    // seguro de caracteres, se ignora y cae a autodetección):
    //   nombre de sensor ("k10temp")   → matchea el `name` del hwmon
    //   dispositivo ("hwmon4")        → /sys/class/hwmon/hwmon4/temp1_input
    //   ruta (a temp*_input o al directorio hwmon)
    // Nunca se interpola un valor sin validar en el texto del comando:
    // la validación va en QML y el valor entra como argumento del `sh -c`.
    readonly property string _tempSensorConfig: {
        const raw = Theme.pick(
            Quickshell.env("SHELL_TEMP_SENSOR"),
            Theme.settingsTempSensor,
            ""
        ).trim();
        // Solo caracteres seguros para sh: letras, dígitos, / _ . -
        return /^[A-Za-z0-9/_.-]+$/.test(raw) ? raw : "";
    }

    property bool tempAvailable: false
    property string tempSource: ""
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

    // El comando emite UNA línea "<fuente> <miligrados>" (dos campos
    // separados por espacios): SplitParser entrega la línea entera y el
    // handler separa ambos campos acá.
    property Process tempProc: Process {
        stdout: SplitParser {
            onRead: data => {
                const fields = data.trim().split(/\s+/);
                if (fields.length !== 2) {
                    root.tempAvailable = false;
                    root.tempSource = "";
                    return;
                }
                const v = parseFloat(fields[1]);
                if (isNaN(v)) {
                    root.tempAvailable = false;
                    root.tempSource = "";
                    return;
                }
                root.tempSource = fields[0];
                root.temp = Math.round(v / 1000);
                root.tempAvailable = true;
            }
        }
    }

    // Script de lectura del sensor (POSIX sh). Emite UNA línea
    // "<fuente> <miligrados>", o nada si no hay lectura. El valor
    // configurado llega como $1 (ya validado en _tempSensorConfig):
    //   1) ruta: al propio temp*_input o al directorio hwmon
    //   2) dispositivo hwmonN
    //   3) nombre de sensor matcheando el `name` del hwmon
    //   4) autodetección por name conocido
    //   5) primer hwmon existente (último recurso, comportamiento actual)
    readonly property string _tempScript: [
        'cfg="$1"',
        'sys=/sys/class/hwmon',
        'if [ -n "$cfg" ]; then',
        '  case "$cfg" in',
        '    */*)',
        '      d=""',
        '      if [ -r "$cfg" ]; then',
        '        d=$(dirname "$cfg")',
        '      elif [ -r "$cfg/temp1_input" ]; then',
        '        d="$cfg"',
        '      fi',
        '      if [ -n "$d" ] && [ -r "$d/temp1_input" ]; then',
        '        s=$(cat "$d/name" 2>/dev/null)',
        '        [ -n "$s" ] || s=$(basename "$d")',
        '        echo "$s $(cat "$d/temp1_input")"',
        '        exit 0',
        '      fi',
        '      ;;',
        '    hwmon[0-9]*)',
        '      if [ -r "$sys/$cfg/temp1_input" ]; then',
        '        s=$(cat "$sys/$cfg/name" 2>/dev/null)',
        '        [ -n "$s" ] || s="$cfg"',
        '        echo "$s $(cat "$sys/$cfg/temp1_input")"',
        '        exit 0',
        '      fi',
        '      ;;',
        '    *)',
        '      for d in "$sys"/hwmon*; do',
        '        if [ "$(cat "$d/name" 2>/dev/null)" = "$cfg" ] && [ -r "$d/temp1_input" ]; then',
        '          echo "$cfg $(cat "$d/temp1_input")"',
        '          exit 0',
        '        fi',
        '      done',
        '      ;;',
        '  esac',
        'fi',
        'for d in "$sys"/hwmon*; do',
        '  n=$(cat "$d/name" 2>/dev/null)',
        '  case "$n" in',
        '    k10temp|coretemp|zenpower|cpu_thermal)',
        '      if [ -r "$d/temp1_input" ]; then',
        '        echo "$n $(cat "$d/temp1_input")"',
        '        exit 0',
        '      fi',
        '      ;;',
        '  esac',
        'done',
        'for d in "$sys"/hwmon*; do',
        '  if [ -r "$d/temp1_input" ]; then',
        '    n=$(cat "$d/name" 2>/dev/null)',
        '    [ -n "$n" ] || n=$(basename "$d")',
        '    echo "$n $(cat "$d/temp1_input")"',
        '    exit 0',
        '  fi',
        'done'
    ].join("\n")

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
        // Reset del estado ANTES de lanzar: si el comando no emite nada
        // (sensor perdido o inexistente), onRead nunca corre y un estado
        // viejo quedaría "disponible" con valor rancio. `temp` NO se
        // resetea (evita parpadeo); el contrato es que los consumidores
        // consulten tempAvailable.
        root.tempAvailable = false;
        root.tempSource = "";
        tempProc.exec(["sh", "-c", root._tempScript, "selene-temp", root._tempSensorConfig]);
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
