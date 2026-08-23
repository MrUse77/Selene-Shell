import QtQuick
import "../../Services"
import "../../Components"

BarWidget {
    id: root

    hoverable: true
    active: ShellState.powerOpen

    height: 32
    width: 38

    Text {
        anchors.centerIn: parent
        text: "󰐥"
        color: Theme.urgent
        font.family: Theme.font
        font.pixelSize: 14
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: ShellState.togglePower()
    }
}
