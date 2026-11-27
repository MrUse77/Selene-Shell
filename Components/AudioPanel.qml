import QtQuick
import "../Services"
import "../Services/AudioDeviceLogic.js" as DeviceLogic

// Contenido del selector de dispositivo de audio: salida activa con su
// volumen y mute, separador y lista de sinks. Lo comparten el popup de la
// barra y la tarjeta del dashboard.
// La navegación por teclado vive en quien lo aloja: este componente solo
// expone `selectedIndex` para que el contenedor la maneje y la dibuje.
Item {
    id: root

    // Fila resaltada por teclado; -1 = ninguna (solo puntero).
    property int selectedIndex: -1
    // El recordatorio de teclas solo tiene sentido donde el contenedor las
    // maneja; el dashboard lo apaga.
    property bool showKeyboardHint: true

    // Se emite después de fijar el sink, para que el contenedor decida si
    // cierra (popup) o se queda abierto (dashboard).
    signal deviceChosen()

    implicitWidth: 340
    implicitHeight: column.implicitHeight + 28

    Column {
        id: column
        anchors.fill: parent
        anchors.margins: 14
        spacing: 0

        // ---- Salida activa ----
        Row {
            width: parent.width
            spacing: 12

            Rectangle {
                width: 42
                height: 42
                radius: 12
                color: Theme.alpha(Theme.accent, 0.14)
                border.width: 1
                border.color: Theme.alpha(Theme.accent, 0.28)

                Text {
                    anchors.centerIn: parent
                    text: Audio.muted ? "󰸈" : "󰕾"
                    color: Audio.muted ? Theme.urgent : Theme.accent
                    font.family: Theme.font
                    font.pixelSize: 20
                }
            }

            Column {
                width: parent.width - 54
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    width: parent.width
                    text: DeviceLogic.sinkLabel(Audio.sink)
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 15
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: DeviceLogic.sinkDetail(Audio.sink)
                    visible: text !== ""
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
        }

        // ---- Volumen de la salida activa ----
        Item {
            width: parent.width
            height: 12
        }

        Row {
            width: parent.width
            spacing: 10

            Item {
                id: track
                width: parent.width - 36 - 26 - 20
                height: 14
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Theme.alpha(Theme.text, 0.10)
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * Math.min(1, Audio.volume)
                    height: 6
                    radius: 3
                    color: Audio.muted ? Theme.urgent : Theme.accent
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(0, Math.min(parent.width - width, parent.width * Math.min(1, Audio.volume) - width / 2))
                    width: 11
                    height: 11
                    radius: 6
                    color: Theme.text
                    border.width: 2
                    border.color: Audio.muted ? Theme.urgent : Theme.accent
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    function seek(mouse) {
                        Audio.setVolume(Math.max(0, Math.min(1, mouse.x / width)));
                    }

                    onClicked: mouse => seek(mouse)
                    onPositionChanged: mouse => {
                        if (pressed) seek(mouse);
                    }
                }
            }

            Text {
                width: 36
                anchors.verticalCenter: parent.verticalCenter
                text: Audio.percent + "%"
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 12
                horizontalAlignment: Text.AlignRight
            }

            Rectangle {
                width: 26
                height: 26
                radius: 8
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.alpha(Theme.text, 0.06)
                border.width: 1
                border.color: Theme.alpha(Theme.text, 0.08)

                Text {
                    anchors.centerIn: parent
                    text: Audio.muted ? "󰸈" : "󰝟"
                    color: Audio.muted ? Theme.urgent : Theme.textDim
                    font.family: Theme.font
                    font.pixelSize: 13
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Audio.toggleMute()
                }
            }
        }

        // ---- Separador ----
        Item {
            width: parent.width
            height: 13
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.alpha(Theme.text, 0.07)
        }

        Text {
            width: parent.width
            topPadding: 11
            bottomPadding: 8
            text: "CAMBIAR SALIDA"
            color: Theme.textDim
            font.family: Theme.font
            font.pixelSize: 10
            font.letterSpacing: 1
        }

        // ---- Selector ----
        Repeater {
            model: Audio.sinks

            delegate: Rectangle {
                id: row

                required property var modelData
                required property int index

                width: column.width
                height: 30
                radius: 8
                color: root.selectedIndex === index || hover.hovered
                    ? Theme.alpha(Theme.accent, 0.10)
                    : "transparent"

                HoverHandler {
                    id: hover
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.right: dot.left
                    anchors.rightMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.label
                    color: row.modelData.isDefault ? Theme.text : Theme.textDim
                    font.family: Theme.font
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Rectangle {
                    id: dot
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6
                    height: 6
                    radius: 3
                    visible: row.modelData.isDefault
                    color: Theme.accent
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Audio.selectSink(row.modelData.node);
                        root.deviceChosen();
                    }
                }
            }
        }

        Text {
            width: parent.width
            topPadding: 10
            visible: root.showKeyboardHint
            text: "↑↓ elegir · ↵ aplicar · ←→ volumen · m silenciar · esc"
            color: Theme.textDim
            font.family: Theme.font
            font.pixelSize: 9
            wrapMode: Text.WordWrap
        }
    }
}
