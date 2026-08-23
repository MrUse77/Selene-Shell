import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../Services"
import "../../Components"

// OSD de volumen: reactivo a PipeWire (cualquier fuente del cambio).
PanelWindow {

    // Capa Overlay: por encima de las ventanas, incluso fullscreen
    WlrLayershell.layer: WlrLayer.Overlay
    // Sin zona exclusiva: flota sobre las ventanas, no les roba lugar
    exclusionMode: ExclusionMode.Ignore
    id: root

    anchors.bottom: true
    margins.bottom: 90
    implicitWidth: 340
    implicitHeight: 56
    color: "transparent"
    visible: showing

    property bool showing: false

    readonly property Timer hideTimer: Timer {
        interval: 2000
        onTriggered: root.showing = false
    }

    function poke() {
        showing = true;
        hideTimer.restart();
    }

    Connections {
        target: Audio

        function onVolumeChanged() { root.poke() }
        function onMutedChanged() { root.poke() }
    }

    Capsule {
        id: capsule
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        alphaBg: 0.94

        scale: root.showing ? 1 : 0.92
        opacity: root.showing ? 1 : 0

        Behavior on scale {
            NumberAnimation { duration: Anim.fast; easing.bezierCurve: Anim.overshot }
        }
        Behavior on opacity {
            NumberAnimation { duration: Anim.fast; easing.bezierCurve: Anim.easeOutQuint }
        }

        Row {
            anchors.centerIn: parent
            spacing: 12

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Audio.muted || Audio.percent === 0 ? "󰸈"
                    : Audio.percent < 34 ? "󰕿"
                    : Audio.percent < 67 ? "󰖀"
                    : "󰕾"
                color: Audio.muted ? Theme.urgent : Theme.accent
                font.family: Theme.font
                font.pixelSize: 20
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 190
                height: 10
                radius: 5
                color: Theme.alpha(Theme.text, 0.12)

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * Math.min(1, Math.max(0, Audio.volume))
                    height: parent.height
                    radius: 5
                    color: Audio.muted ? Theme.urgent : Theme.accent

                    Behavior on width {
                        NumberAnimation { duration: Anim.fast; easing.bezierCurve: Anim.smooth }
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Audio.percent + "%"
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: 14
                font.bold: true
            }
        }
    }
}
