import QtQuick
import "../Services"

// Widget dentro de la barra única: contenido plano, sin fondo propio.
// Se ilumina (moonlight) en hover o cuando está activo (overlay abierto).
Item {
    id: root

    property bool hoverable: false
    property bool active: false

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.alpha(Theme.accent, 0.12)
        opacity: (root.hoverable && hh.hovered) || root.active ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Anim.fast; easing.bezierCurve: Anim.smooth }
        }
    }

    HoverHandler {
        id: hh
        enabled: root.hoverable
        cursorShape: Qt.PointingHandCursor
    }
}
