import QtQuick
import "../Services"

// Tarjeta bento para el dashboard: radio grande, borde tenue.
Rectangle {
    id: root

    radius: Theme.rCard
    color: Theme.alpha(Theme.bg, 0.92)
    border.width: 1
    border.color: Theme.alpha(Theme.accent, 0.14)

    Behavior on border.color {
        ColorAnimation { duration: Anim.fast; easing.bezierCurve: Anim.smooth }
    }
    Behavior on color {
        ColorAnimation { duration: Anim.fast; easing.bezierCurve: Anim.smooth }
    }
}
