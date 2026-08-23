import QtQuick
import Quickshell
import "../../Services"
import "../../Components"

// Volumen del sink por defecto: clic abre pavucontrol, rueda ajusta.
BarWidget {
    id: root

    hoverable: true

    readonly property string icon:
        Audio.muted || Audio.percent === 0 ? "󰸈"
        : Audio.percent < 34 ? "󰕿"
        : Audio.percent < 67 ? "󰖀"
        : "󰕾"

    height: 32
    width: row.implicitWidth + 16

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: Audio.muted ? Theme.urgent : Theme.text
            font.family: Theme.font
            font.pixelSize: 15
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: (Audio.muted ? "×" : Audio.percent) + "%"
            color: Theme.textDim
            font.family: Theme.fontMono
            font.pixelSize: 12
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["pavucontrol"])
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => Audio.stepVolume(event.angleDelta.y > 0 ? 5 : -5)
    }
}
