import QtQuick
import "../../Services"
import "../../Components"

// Volumen del sink por defecto: clic abre el selector de dispositivo, rueda ajusta.
BarWidget {
    id: root

    hoverable: true
    active: ShellState.audioPickerOpen && ShellState.audioPickerScreen === (screen?.name ?? "")

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
            id: value
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
        onClicked: {
            // El popup se centra en el número del volumen. mapToItem(null) da
            // coordenadas de la superficie de la barra, que está insetada por
            // barMarginSide; se suma para pasar un centro de pantalla.
            const centerX = value.mapToItem(null, value.width / 2, 0).x + Geometry.barMarginSide;
            ShellState.toggleAudioPicker(screen?.name ?? "", centerX);
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => Audio.stepVolume(event.angleDelta.y > 0 ? 5 : -5)
    }
}
