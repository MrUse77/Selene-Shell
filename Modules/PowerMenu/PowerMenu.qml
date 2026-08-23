import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../Services"
import "../../Components"

// Overlay de sesión con colores semánticos del tema.
PanelWindow {

    // Capa Overlay: por encima de las ventanas, incluso fullscreen
    WlrLayershell.layer: WlrLayer.Overlay
    // Sin zona exclusiva: flota sobre las ventanas, no les roba lugar
    exclusionMode: ExclusionMode.Ignore
    id: root

    readonly property var targetScreen:
        Quickshell.screens.find(s => s.name === (Hyprland.focusedMonitor?.name ?? ""))
        ?? Quickshell.screens[0] ?? null

    screen: targetScreen
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    color: Theme.alpha(Theme.bgDeep, 0.6)
    visible: ShellState.powerOpen
    focusable: ShellState.powerOpen

    onVisibleChanged: {
        if (visible) content.forceActiveFocus();
    }

    function close() {
        ShellState.powerOpen = false;
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Item {
        id: content
        anchors.fill: parent

        Keys.onEscapePressed: root.close()

        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.96

        Behavior on opacity {
            NumberAnimation { duration: Anim.fast; easing.bezierCurve: Anim.easeOutQuint }
        }
        Behavior on scale {
            NumberAnimation { duration: Anim.normal; easing.bezierCurve: Anim.overshot }
        }

        Column {
            anchors.centerIn: parent
            spacing: 28

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Sesión"
                color: Theme.textDim
                font.family: Theme.font
                font.pixelSize: 13
                font.bold: true
            }

            Row {
                spacing: 18

                Repeater {
                    model: [
                        { icon: "󰐥", label: "Apagar", color: "urgent", cmd: ["systemctl", "poweroff"] },
                        { icon: "󰜉", label: "Reiniciar", color: "purple", cmd: ["systemctl", "reboot"] },
                        { icon: "󰤄", label: "Suspender", color: "cyan", cmd: ["systemctl", "suspend"] },
                        { icon: "󰍁", label: "Bloquear", color: "accent", cmd: ["hyprlock"] },
                        { icon: "󰿅", label: "Salir", color: "warning", cmd: ["hyprctl", "dispatch", "exit"] }
                    ]

                    delegate: Capsule {
                        id: act

                        required property var modelData

                        readonly property color tint:
                            modelData.color === "urgent" ? Theme.urgent
                            : modelData.color === "purple" ? Theme.purple
                            : modelData.color === "cyan" ? Theme.cyan
                            : modelData.color === "warning" ? Theme.warning
                            : Theme.accent

                        width: 84
                        height: 84
                        alphaBg: hover.hovered ? 0.96 : 0.88

                        Behavior on alphaBg {}

                        Column {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: act.modelData.icon
                                color: act.tint
                                font.family: Theme.font
                                font.pixelSize: 26
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: act.modelData.label
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 11
                            }
                        }

                        HoverHandler {
                            id: hover
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: Quickshell.execDetached(act.modelData.cmd)
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "esc para cancelar"
                color: Theme.textDim
                font.family: Theme.font
                font.pixelSize: 10
            }
        }
    }
}
