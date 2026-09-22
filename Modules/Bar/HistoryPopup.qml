import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../Services"
import "../../Components"

// Historial de notificaciones bajo la campana.
PanelWindow {

    // Capa Overlay: por encima de las ventanas, incluso fullscreen
    WlrLayershell.layer: WlrLayer.Overlay
    // Sin zona exclusiva: flota sobre las ventanas, no les roba lugar
    exclusionMode: ExclusionMode.Ignore
    id: root

    property var modelData
    readonly property string screenName: modelData?.name ?? ""

    screen: modelData
    visible: ShellState.historyOpen && ShellState.historyScreen === screenName
    anchors {
        top: true
        right: true
    }
    // Gap de diseño bajo la barra e inset derecho: 4 y 4 reproducen el top
    // previo (10 + 44 + 4 = 58) y el right previo (14 + 4 = 18).
    readonly property int gapBelowBar: 4
    readonly property int rightInset: 4
    margins {
        top: Geometry.panelTop(gapBelowBar)
        right: Geometry.panelRight(rightInset)
    }
    implicitWidth: 380
    implicitHeight: 420
    color: "transparent"
    aboveWindows: true

    HyprlandFocusGrab {
        active: root.visible
        onCleared: ShellState.historyOpen = false
    }

    Card {
        anchors.fill: parent

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Item {
                width: parent.width
                height: 26

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Notificaciones"
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰑑 limpiar"
                    color: Theme.textDim
                    font.family: Theme.font
                    font.pixelSize: 11

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShellState.clearHistory()
                    }
                }
            }

            ListView {
                id: list
                width: parent.width
                height: parent.height - 36
                clip: true
                spacing: 8
                model: ShellState.history

                delegate: Rectangle {
                    id: hd

                    required property string app
                    required property string summary
                    required property string body
                    required property int urgency
                    required property string time

                    width: list.width
                    height: histCol.implicitHeight + 18
                    radius: Theme.rInner
                    color: Theme.alpha(Theme.surface, 0.5)

                    Column {
                        id: histCol
                        x: 9
                        y: 9
                        width: parent.width - 18
                        spacing: 2

                        Text {
                            text: hd.app + "  ·  " + hd.time
                            color: Theme.textDim
                            font.family: Theme.font
                            font.pixelSize: 10
                        }

                        Text {
                            width: parent.width
                            text: summary
                            elide: Text.ElideRight
                            color: urgency === 2 ? Theme.urgent : Theme.text
                            font.family: Theme.font
                            font.pixelSize: 12
                            font.bold: true
                        }

                        Text {
                            visible: body !== ""
                            width: parent.width
                            text: body
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            color: Theme.textDim
                            font.family: Theme.font
                            font.pixelSize: 11
                        }
                    }
                }

                Text {
                    visible: ShellState.history.count === 0
                    anchors.centerIn: parent
                    text: "Sin notificaciones"
                    color: Theme.textDim
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }
        }
    }
}
