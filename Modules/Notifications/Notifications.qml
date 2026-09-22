import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.Notifications
import "../../Services"
import "../../Components"

// Notificaciones de Selene: popups arriba a la derecha (bajo la barra).
// Si dunst u otro daemon posee el bus, el servidor no registra y el resto
// de la shell sigue funcionando (degradación elegante, ver spec).
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
        right: true
    }
    // Gap de diseño bajo la barra e inset derecho: 6 y 4 reproducen el top
    // previo (10 + 44 + 6 = 60) y el right previo (14 + 4 = 18).
    readonly property int gapBelowBar: 6
    readonly property int rightInset: 4
    margins {
        top: Geometry.panelTop(gapBelowBar)
        right: Geometry.panelRight(rightInset)
    }
    implicitWidth: 380
    implicitHeight: popupsCol.childrenRect.height
    color: "transparent"
    aboveWindows: true

    NotificationServer {
        id: server

        actionsSupported: true
        imageSupported: true
        keepOnReload: true

        onNotification: notif => root.handle(notif)
    }

    property ListModel popups: ListModel {}
    property int uidSeq: 0

    readonly property var urgencyColor: n =>
        n.urgency === NotificationUrgency.Critical ? Theme.urgent
        : n.urgency === NotificationUrgency.Low ? Theme.gray
        : Theme.accent

    function handle(n) {
        n.tracked = true;
        ShellState.addHistory(n.appName, n.summary, n.body, n.urgency);

        if (ShellState.dnd && n.urgency !== NotificationUrgency.Critical) {
            n.expire();
            return;
        }

        uidSeq++;
        popups.append({ uid: uidSeq, n: n });

        while (popups.count > 4) {
            const oldest = popups.get(0).n;
            popups.remove(0);
            oldest.expire();
        }
    }

    function removeUid(uid) {
        for (let i = 0; i < popups.count; i++) {
            if (popups.get(i).uid === uid) {
                popups.remove(i);
                return;
            }
        }
    }

    function closeNotif(n, uid) {
        n.dismiss();
        removeUid(uid);
    }

    Column {
        id: popupsCol
        spacing: 8

        Repeater {
            model: root.popups

            delegate: Card {
                id: popup

                required property int uid
                required property var n

                readonly property bool critical:
                    n.urgency === NotificationUrgency.Critical

                width: 380
                height: contentCol.implicitHeight + 24
                border.color: Theme.alpha(root.urgencyColor(n), critical ? 0.6 : 0.3)

                // Expiración (las críticas no se auto-cierran).
                // Solo expire(): close() emite closed() de forma síncrona y
                // Connections.onClosed deshace el uid con el delegate vivo.
                // Remover acá tras expire() resolvía ids (root) sobre un
                // contexto ya destruido -> ReferenceError repetido en el log.
                Timer {
                    interval: popup.n.expireTimeout > 0 ? popup.n.expireTimeout : 5000
                    running: !popup.critical
                    repeat: false
                    onTriggered: popup.n.expire()
                }

                Connections {
                    target: popup.n

                    function onClosed() { root.removeUid(popup.uid) }
                }

                // Entrada con easeOutQuint, como layersIn del compositor
                opacity: 1
                scale: 1
                Component.onCompleted: {
                    opacity = 0;
                    scale = 0.95;
                    opacity = 1;
                    scale = 1;
                }

                Behavior on opacity {
                    NumberAnimation { duration: Anim.fast; easing.bezierCurve: Anim.easeOutQuint }
                }
                Behavior on scale {
                    NumberAnimation { duration: Anim.fast; easing.bezierCurve: Anim.easeOutQuint }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.closeNotif(popup.n, popup.uid)
                }

                Column {
                    id: contentCol
                    x: 12
                    y: 12
                    width: parent.width - 24
                    spacing: 5

                    Row {
                        spacing: 10

                        IconImage {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            height: 30
                            source: popup.n.image || popup.n.appIcon || ""
                        }

                        Column {
                            width: parent.width - 44
                            spacing: 1

                            Text {
                                width: parent.width
                                text: popup.n.appName || "Sistema"
                                elide: Text.ElideRight
                                color: Theme.textDim
                                font.family: Theme.font
                                font.pixelSize: 10
                            }
                            Text {
                                width: parent.width
                                text: popup.n.summary
                                elide: Text.ElideRight
                                color: root.urgencyColor(popup.n)
                                font.family: Theme.font
                                font.pixelSize: 13
                                font.bold: true
                            }
                        }
                    }

                    Text {
                        visible: popup.n.body !== ""
                        width: parent.width
                        text: popup.n.body
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 11
                    }

                    Row {
                        visible: popup.n.actions.length > 0
                        spacing: 8

                        Repeater {
                            model: popup.n.actions

                            delegate: Rectangle {
                                required property var modelData

                                height: 26
                                width: actionLabel.implicitWidth + 20
                                radius: height / 2
                                color: Theme.alpha(Theme.accent, 0.14)
                                border.width: 1
                                border.color: Theme.alpha(Theme.accent, 0.35)

                                Text {
                                    id: actionLabel
                                    anchors.centerIn: parent
                                    text: modelData.text
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: 10
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        modelData.invoke();
                                        if (!popup.n.resident)
                                            root.closeNotif(popup.n, popup.uid);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
