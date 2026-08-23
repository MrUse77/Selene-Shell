import QtQuick
import "../Services"

// La pieza firma de Selene: cápsula translúcida con borde de acento.
// `glow` marca el elemento activo (moonlight): borde pleno + halo tenue.
Rectangle {
    id: root

    property bool glow: false
    property real alphaBg: 0.88

    radius: height / 2
    color: Theme.alpha(Theme.bg, alphaBg)
    border.width: 1
    border.color: Theme.alpha(Theme.accent, glow ? 0.55 : 0.16)

    // Halo lunar: anillo externo de baja alfa, solo cuando está activo.
    Rectangle {
        anchors.centerIn: parent
        width: parent.width + 6
        height: parent.height + 6
        radius: height / 2
        color: "transparent"
        border.width: 3
        border.color: Theme.alpha(Theme.accent, 0.12)
        visible: root.glow
        opacity: root.glow ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Anim.fast; easing.bezierCurve: Anim.smooth }
        }
    }

    Behavior on border.color {
        ColorAnimation { duration: Anim.fast; easing.bezierCurve: Anim.smooth }
    }
    Behavior on color {
        ColorAnimation { duration: Anim.fast; easing.bezierCurve: Anim.smooth }
    }
}
