import QtQuick
import Quickshell
import "../../Services"
import "../../Components"

// Actualizaciones pendientes; visible solo cuando hay.
BarWidget {
    id: root

    hoverable: true

    visible: Updates.count > 0
    height: 32
    width: row.implicitWidth + 16

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰮯"
            color: Theme.warning
            font.family: Theme.font
            font.pixelSize: 15
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Updates.count
            color: Theme.warning
            font.family: Theme.fontMono
            font.pixelSize: 12
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["ghostty", "-e", "paru"])
    }
}
