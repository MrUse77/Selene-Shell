import QtQuick
import "../Services"

// Slider pill con relleno de color — estilo Selene.
Item {
    id: root

    property real value: 0           // 0..1
    property color fillColor: Theme.accent
    property bool live: true         // emite `moved` continuamente
    signal moved(real value)

    implicitWidth: 200
    implicitHeight: 22

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 10
        radius: height / 2
        color: Theme.alpha(Theme.text, 0.12)
    }

    Rectangle {
        id: fill
        anchors.verticalCenter: parent.verticalCenter
        x: 0
        width: parent.width * Math.min(1, Math.max(0, root.value))
        height: 10
        radius: height / 2
        color: root.fillColor

        Behavior on width {
            NumberAnimation { duration: Anim.fast; easing.bezierCurve: Anim.smooth }
        }
    }

    Rectangle {
        id: handle
        anchors.verticalCenter: parent.verticalCenter
        x: root.width * Math.min(1, Math.max(0, root.value)) - width / 2
        width: 18
        height: 18
        radius: 9
        color: Theme.text
        border.width: 3
        border.color: root.fillColor

        Behavior on x {
            NumberAnimation { duration: Anim.fast; easing.bezierCurve: Anim.smooth }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.emit(mouse.x)
        onPositionChanged: mouse => {
            if (pressed && root.live) root.emit(mouse.x);
        }
    }

    function emit(x) {
        moved(Math.min(1, Math.max(0, x / width)));
    }
}
