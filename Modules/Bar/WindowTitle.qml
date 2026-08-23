import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../../Services"
import "../../Components"

// Título de la ventana enfocada de este monitor.
BarWidget {
    id: root

    property var screen

    readonly property var tl: {
        const t = Hyprland.activeToplevel;
        return t && t.monitor === Hyprland.monitorFor(screen ?? null) ? t : null;
    }

    visible: tl != null && tl.title !== ""
    height: 32
    width: Math.min(320, title.implicitWidth + 16)

    Behavior on width {
        NumberAnimation { duration: Anim.fast; easing.bezierCurve: Anim.smooth }
    }

    Text {
        id: title
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 20
        text: root.tl?.title ?? ""
        elide: Text.ElideRight
        color: Theme.textDim
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
    }
}
