import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../../Services"
import "../../Components"

// Workspaces del monitor (split-monitor-workspaces: 5 por monitor).
// El indicador activo se desliza — movimiento de marea, no teleport.
Item {
    id: root

    property var screen

    implicitHeight: 34
    implicitWidth: row.implicitWidth

    readonly property var monitor: Hyprland.monitorFor(screen ?? null)

    readonly property var wss: {
        const out = [];
        const vals = Hyprland.workspaces.values;
        for (let i = 0; i < vals.length; i++) {
            if (vals[i].monitor === monitor) out.push(vals[i]);
        }
        out.sort((a, b) => a.id - b.id);
        // Fallback si aún no existen los persistentes
        if (out.length === 0) {
            for (let n = 1; n <= 5; n++)
                out.push({ id: n, name: String(n), active: false, urgent: false });
        }
        return out;
    }

    readonly property int activeIndex: {
        for (let i = 0; i < wss.length; i++)
            if (wss[i].active) return i;
        return -1;
    }

    property var buttons: []

    readonly property var indicatorTarget:
        activeIndex >= 0 && activeIndex < buttons.length ? buttons[activeIndex] : null

    // El monitor sin foco se atenúa suavemente
    opacity: Hyprland.focusedMonitor === monitor ? 1 : 0.7

    Behavior on opacity {
        NumberAnimation { duration: Anim.slow; easing.bezierCurve: Anim.smooth }
    }

    Rectangle {
        id: indicator
        y: (parent.height - 26) / 2
        height: 26
        radius: 13
        width: indicatorTarget ? indicatorTarget.width : 0
        x: indicatorTarget ? indicatorTarget.x : 0
        color: Theme.alpha(Theme.accent, 0.16)
        border.width: 1
        border.color: Theme.alpha(Theme.accent, 0.45)

        Behavior on x {
            NumberAnimation { duration: Anim.normal; easing.bezierCurve: Anim.gentle }
        }
        Behavior on width {
            NumberAnimation { duration: Anim.fast; easing.bezierCurve: Anim.gentle }
        }
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Repeater {
            model: root.wss

            delegate: Item {
                id: wb

                required property var modelData

                width: label.implicitWidth + 16
                height: 26

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: wb.modelData.name ?? String(wb.modelData.id)
                    color: wb.modelData.urgent ? Theme.urgent
                         : wb.modelData.active ? Theme.text
                         : Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: 12
                    font.bold: wb.modelData.active
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const ws = wb.modelData;
                        if (ws.activate) ws.activate();
                        else Hyprland.dispatch("workspace " + ws.id);
                    }
                }
            }

            onItemAdded: (index, item) => {
                const btns = root.buttons.slice();
                btns.splice(index, 0, item);
                root.buttons = btns;
            }
            onItemRemoved: (index, item) => {
                const btns = root.buttons.slice();
                const i = btns.indexOf(item);
                if (i >= 0) btns.splice(i, 1);
                root.buttons = btns;
            }
        }
    }
}
