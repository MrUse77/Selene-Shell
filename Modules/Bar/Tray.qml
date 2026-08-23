import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import "../../Services"
import "../../Components"

// Bandeja del sistema con menús nativos.
BarWidget {
    id: root

    readonly property var items: SystemTray.items.values

    visible: items.length > 0
    height: 32
    width: trayRow.implicitWidth + 14

    Row {
        id: trayRow
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: root.items

            delegate: Item {
                id: trayItem

                required property var modelData

                width: 22
                height: 22

                IconImage {
                    anchors.fill: parent
                    source: trayItem.modelData.icon
                }

                QsMenuAnchor {
                    id: menuAnchor
                    menu: trayItem.modelData.hasMenu ? trayItem.modelData.menu : null
                    anchor.item: trayItem
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        const it = trayItem.modelData;
                        if (mouse.button === Qt.MiddleButton) {
                            it.secondaryActivate();
                        } else if (mouse.button === Qt.RightButton) {
                            if (it.hasMenu) menuAnchor.open();
                            else it.secondaryActivate();
                        } else {
                            if (it.onlyMenu && it.hasMenu) menuAnchor.open();
                            else it.activate();
                        }
                    }
                }
            }
        }
    }
}
