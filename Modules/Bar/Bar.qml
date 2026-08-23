import QtQuick
import Quickshell
import "../../Services"
import "../../Components"
import "."

// Barra de Selene: una sola superficie continua (cápsula ancha) por monitor.
// Los widgets viven adentro, separados por divisores sutiles; el borde de
// acento se enciende (moonlight) cuando hay un overlay abierto.
PanelWindow {
    id: root

    property var modelData  // ShellScreen, provisto por Variants

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: 10
        left: 14
        right: 14
    }
    implicitHeight: 44
    exclusiveZone: 44
    color: "transparent"

    readonly property bool anyOverlay: OverlayCoordinator.isOpen

    component Divider: Item {
        width: 10
        height: 32

        Rectangle {
            anchors.centerIn: parent
            width: 1
            height: 16
            color: Theme.alpha(Theme.text, 0.12)
        }
    }

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: height / 2
        color: Theme.alpha(Theme.bg, 0.88)
        border.width: 1
        border.color: Theme.alpha(Theme.accent, root.anyOverlay ? 0.5 : 0.16)

        Behavior on border.color {
            ColorAnimation { duration: Anim.fast; easing.bezierCurve: Anim.smooth }
        }
        Behavior on color {
            ColorAnimation { duration: Anim.fast; easing.bezierCurve: Anim.smooth }
        }

        Item {
            anchors.fill: parent

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                // Orbe launcher (\uF303 = glifo Arch de Nerd Font)
                BarWidget {
                    hoverable: true
                    active: OverlayCoordinator.launcherOpen
                    width: 42
                    height: 32

                    Text {
                        anchors.centerIn: parent
                        text: "\uF303"
                        color: Theme.accent
                        font.family: Theme.font
                        font.pixelSize: 17
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: OverlayCoordinator.toggle("launcher", {
                            source: "widget",
                            screen: root.modelData,
                            explicit: true
                        })
                    }
                }

                Divider {}

                Workspaces {
                    screen: root.modelData
                }

                Divider {}

                WindowTitle {
                    screen: root.modelData
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                MediaWidget {
                    screen: root.modelData
                }

                Divider {}

                UpdatesWidget {}
                AudioWidget {}
                HardwareWidget {}

                Divider {}

                Tray {}
                NotifsWidget {
                    screen: root.modelData
                }
                ClockWidget {
                    screen: root.modelData
                }

                Divider {}

                // Botón del dashboard (centro de control)
                BarWidget {
                    hoverable: true
                    active: OverlayCoordinator.dashboardOpen
                    width: 40
                    height: 32

                    Text {
                        anchors.centerIn: parent
                        text: "󰒓"
                        color: Theme.cyan
                        font.family: Theme.font
                        font.pixelSize: 15
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: OverlayCoordinator.toggle("dashboard", {
                            source: "widget",
                            screen: root.modelData,
                            explicit: true
                        })
                    }
                }

                PowerButton {
                    screen: root.modelData
                }
            }
        }
    }
}
