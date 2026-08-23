import QtQuick
import "../Services"

// Medidor circular fino con etiqueta y color de alerta opcional.
Canvas {
    id: root

    property real value: 0            // 0..1
    property string label: ""
    property string valueText: ""
    property color barColor: Theme.accent
    property color alertColor: Theme.urgent
    property real alertAt: 1.01       // >1: sin alerta

    implicitWidth: 86
    implicitHeight: 86
    antialiasing: true

    readonly property bool alert: value * 100 >= alertAt

    onValueChanged: requestPaint()
    onBarColorChanged: requestPaint()
    onAlertChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.lineCap = "round";

        const cx = width / 2, cy = height / 2;
        const r = Math.min(width, height) / 2 - 4;

        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, 2 * Math.PI);
        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.08);
        ctx.lineWidth = 5;
        ctx.stroke();

        ctx.beginPath();
        ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * Math.min(1, Math.max(0, value)));
        ctx.strokeStyle = alert ? alertColor : barColor;
        ctx.lineWidth = 5;
        ctx.stroke();
    }

    Column {
        anchors.centerIn: parent
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.valueText
            color: root.alert ? root.alertColor : Theme.text
            font.family: Theme.fontMono
            font.pixelSize: 15
            font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            color: Theme.textDim
            font.family: Theme.font
            font.pixelSize: 10
        }
    }

    Behavior on value {
        NumberAnimation { duration: Anim.slow; easing.bezierCurve: Anim.smooth }
    }
}
