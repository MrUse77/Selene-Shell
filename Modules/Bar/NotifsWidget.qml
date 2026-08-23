import QtQuick
import "../../Services"
import "../../Components"

// Campana con badge de no leídas; clic abre el historial.
BarWidget {
    id: root

    property var screen

    hoverable: true
    active: ShellState.historyOpen && ShellState.historyScreen === (screen?.name ?? "")

    height: 32
    width: row.implicitWidth + 18

    readonly property color iconColor: ShellState.dnd ? Theme.warning : Theme.text

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ShellState.dnd ? "󰂛" : "󰂚"
            color: root.iconColor
            font.family: Theme.font
            font.pixelSize: 14
        }

        Text {
            visible: ShellState.unread > 0
            anchors.verticalCenter: parent.verticalCenter
            text: ShellState.unread > 99 ? "99+" : ShellState.unread
            color: Theme.accent
            font.family: Theme.fontMono
            font.pixelSize: 12
            font.bold: true
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: ShellState.toggleHistory(screen?.name ?? "")
    }
}
