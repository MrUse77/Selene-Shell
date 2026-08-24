import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../../Services"
import "../../Components"

// Dashboard bento de Selene: drawer derecho en el monitor enfocado.
PanelWindow {

    // Capa Overlay: por encima de las ventanas, incluso fullscreen
    WlrLayershell.layer: WlrLayer.Overlay
    // Sin zona exclusiva: flota sobre las ventanas, no les roba lugar
    exclusionMode: ExclusionMode.Ignore
    id: root

    property var modelData

    readonly property var player: Media.player

    screen: modelData
    anchors {
        top: true
        right: true
        bottom: true
    }
    margins {
        top: 56
        right: 14
        bottom: 14
    }
    implicitWidth: 470
    color: "transparent"
    visible: OverlayCoordinator.dashboardOpen && OverlayCoordinator.targetScreen === modelData
    // Hyprland renderiza fullscreen por encima de toda capa layer-shell
    // salvo que la superficie tenga foco de teclado: con focusable mientras
    // está abierto, el dashboard queda encima incluso de ventanas fullscreen.
    focusable: OverlayCoordinator.dashboardOpen && OverlayCoordinator.targetScreen === modelData

    onVisibleChanged: {
        Hardware.active = true;
        if (visible) refreshBt();
    }

    // ---- Bluetooth ----
    property bool btOn: false

    readonly property Process btProc: Process {
        stdout: SplitParser {
            onRead: data => {
                if (data.includes("Powered: yes")) root.btOn = true;
                else if (data.includes("Powered: no")) root.btOn = false;
            }
        }
    }

    function refreshBt() {
        btProc.exec(["bluetoothctl", "show"]);
    }

    function toggleBt() {
        btOn = !btOn;
        Quickshell.execDetached(["bluetoothctl", "power", btOn ? "on" : "off"]);
        Qt.callLater(refreshBt);
    }

    function fmtTime(sec) {
        if (!isFinite(sec) || sec < 0) sec = 0;
        const m = Math.floor(sec / 60);
        const s = Math.floor(sec % 60);
        return m + ":" + String(s).padStart(2, "0");
    }

    // Drawer deslizante
    Rectangle {
        id: drawer
        anchors.fill: parent
        radius: Theme.rCard
        color: Theme.alpha(Theme.bg, 0.96)
        border.width: 1
        border.color: Theme.alpha(Theme.accent, 0.16)
        clip: true

        x: root.visible ? 0 : parent.width + 20
        opacity: root.visible ? 1 : 0

        Behavior on x {
            NumberAnimation { duration: Anim.slower; easing.bezierCurve: Anim.easeOutQuint }
        }
        Behavior on opacity {
            NumberAnimation { duration: Anim.slow; easing.bezierCurve: Anim.smooth }
        }

        Flickable {
            anchors.fill: parent
            contentWidth: width
            contentHeight: column.implicitHeight + 32
            clip: true

            Column {
                id: column
                x: 16
                y: 16
                width: parent.width - 32
                spacing: 12

                // ---- Usuario + luna ----
                Card {
                    width: parent.width
                    height: 84

                    Row {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 14

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 56
                            height: 56
                            radius: 28
                            color: Theme.alpha(Theme.accent, 0.18)
                            border.width: 1
                            border.color: Theme.alpha(Theme.accent, 0.4)

                            Text {
                                anchors.centerIn: parent
                                text: (Quickshell.env("USER") ?? "a").charAt(0).toUpperCase()
                                color: Theme.accent
                                font.family: Theme.font
                                font.pixelSize: 24
                                font.bold: true
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Text {
                                text: Quickshell.env("USER") ?? "agustin"
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 18
                                font.bold: true
                            }
                            Text {
                                text: "encendido " + Hardware.uptimeText()
                                color: Theme.textDim
                                font.family: Theme.font
                                font.pixelSize: 11
                            }
                        }

                        Item { width: 8; height: 1 }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            MoonDisc {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 30
                                height: 30
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Moon.name
                                color: Theme.textDim
                                font.family: Theme.font
                                font.pixelSize: 10
                            }
                        }
                    }
                }

                // ---- Toggles ----
                Row {
                    width: parent.width
                    spacing: 12

                    Card {
                        width: (parent.width - 12) / 2
                        height: 52

                        Row {
                            anchors.centerIn: parent
                            spacing: 10

                            Text {
                                text: root.btOn ? "󰂯" : "󰂲"
                                color: root.btOn ? Theme.cyan : Theme.textDim
                                font.family: Theme.font
                                font.pixelSize: 17
                            }
                            Text {
                                text: root.btOn ? "Bluetooth" : "Bluetooth off"
                                color: root.btOn ? Theme.text : Theme.textDim
                                font.family: Theme.font
                                font.pixelSize: 12
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleBt()
                        }
                    }

                    Card {
                        width: (parent.width - 12) / 2
                        height: 52

                        Row {
                            anchors.centerIn: parent
                            spacing: 10

                            Text {
                                text: ShellState.dnd ? "󰂛" : "󰂚"
                                color: ShellState.dnd ? Theme.warning : Theme.textDim
                                font.family: Theme.font
                                font.pixelSize: 17
                            }
                            Text {
                                text: ShellState.dnd ? "No molestar" : "Notificaciones"
                                color: ShellState.dnd ? Theme.text : Theme.textDim
                                font.family: Theme.font
                                font.pixelSize: 12
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ShellState.dnd = !ShellState.dnd
                        }
                    }
                }

                // ---- Volumen ----
                Card {
                    width: parent.width
                    height: 66

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        spacing: 12

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Audio.muted || Audio.percent === 0 ? "󰸈"
                                : Audio.percent < 34 ? "󰕿"
                                : Audio.percent < 67 ? "󰖀"
                                : "󰕾"
                            color: Audio.muted ? Theme.urgent : Theme.purple
                            font.family: Theme.font
                            font.pixelSize: 18

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Audio.toggleMute()
                            }
                        }

                        StyledSlider {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 130
                            value: Math.min(1, Audio.volume)
                            fillColor: Audio.muted ? Theme.urgent : Theme.purple
                            onMoved: v => {
                                Audio.setVolume(v);
                                if (Audio.muted && v > 0) Audio.toggleMute();
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Audio.percent + "%"
                            color: Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: 13
                            font.bold: true
                        }
                    }
                }

                // ---- Recursos ----
                Card {
                    width: parent.width
                    height: 120

                    Row {
                        anchors.centerIn: parent
                        spacing: 36

                        Gauge {
                            value: Hardware.cpu / 100
                            label: "CPU"
                            valueText: Math.round(Hardware.cpu) + "%"
                            barColor: Theme.urgent
                            alertAt: Hardware.cpuCrit
                        }
                        Gauge {
                            value: Hardware.ram / 100
                            label: "RAM"
                            valueText: Math.round(Hardware.ram) + "%"
                            barColor: Theme.accent
                            alertAt: Hardware.ramWarn
                        }
                        Gauge {
                            value: Hardware.disk / 100
                            label: "DISCO"
                            valueText: Math.round(Hardware.disk) + "%"
                            barColor: Theme.success
                        }
                    }
                }

                // ---- Medios ----
                Card {
                    width: parent.width
                    height: !Media.hasPlayers ? 64 : Media.hasMetadata ? 210 : 94

                    Text {
                        anchors.centerIn: parent
                        visible: !Media.hasPlayers
                        text: "No media players"
                        color: Theme.textDim
                        font.family: Theme.font
                        font.pixelSize: 13
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 14
                        visible: Media.hasPlayers
                        spacing: 8

                        Row {
                            width: parent.width
                            height: 20
                            spacing: 8

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - (Media.playerCount > 1 ? 104 : 0)
                                text: Media.identity
                                elide: Text.ElideRight
                                color: Theme.textDim
                                font.family: Theme.font
                                font.pixelSize: 11
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: Media.playerCount > 1
                                text: "󰒮"
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 14

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Media.selectPreviousPlayer()
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: Media.playerCount > 1
                                text: (Media.playerIndex + 1) + "/" + Media.playerCount
                                color: Theme.textDim
                                font.family: Theme.fontMono
                                font.pixelSize: 10
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: Media.playerCount > 1
                                text: "󰒭"
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 14

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Media.selectNextPlayer()
                                }
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: !Media.hasMetadata
                            text: "Nothing playing"
                            color: Theme.textDim
                            font.family: Theme.font
                            font.pixelSize: 13
                        }

                        Row {
                            width: parent.width
                            height: 96
                            visible: Media.hasMetadata
                            spacing: 12

                            Rectangle {
                                width: 96
                                height: 96
                                radius: Theme.rInner
                                color: Theme.alpha(Theme.accent, 0.12)
                                clip: true

                                Image {
                                    id: artwork
                                    anchors.fill: parent
                                    source: root.player?.trackArtUrl ?? ""
                                    visible: source.toString() !== "" && status !== Image.Error
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: artwork.source.toString() === "" || artwork.status === Image.Error
                                    text: "󰎈"
                                    color: Theme.accent
                                    font.family: Theme.font
                                    font.pixelSize: 34
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 108
                                spacing: 4

                                Text {
                                    width: parent.width
                                    text: root.player?.trackTitle ?? ""
                                    elide: Text.ElideRight
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Text {
                                    width: parent.width
                                    text: root.player?.trackArtist ?? ""
                                    elide: Text.ElideRight
                                    color: Theme.textDim
                                    font.family: Theme.font
                                    font.pixelSize: 11
                                }

                                Text {
                                    width: parent.width
                                    visible: text !== ""
                                    text: root.player?.trackAlbum ?? ""
                                    elide: Text.ElideRight
                                    color: Theme.textDim
                                    font.family: Theme.font
                                    font.pixelSize: 10
                                }

                                StyledSlider {
                                    width: parent.width
                                    visible: Media.canSeek
                                    value: Media.length > 0 ? Media.position / Media.length : 0
                                    fillColor: Theme.accent
                                    onMoved: value => Media.seekTo(value * Media.length)
                                }

                                Row {
                                    width: parent.width
                                    visible: Media.canSeek

                                    Text {
                                        text: root.fmtTime(Media.position)
                                        color: Theme.textDim
                                        font.family: Theme.fontMono
                                        font.pixelSize: 10
                                    }

                                    Item { width: parent.width - 70; height: 1 }

                                    Text {
                                        text: root.fmtTime(Media.length)
                                        color: Theme.textDim
                                        font.family: Theme.fontMono
                                        font.pixelSize: 10
                                    }
                                }
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: Media.hasMetadata
                            spacing: 22

                            Text {
                                text: "󰒮"
                                color: Media.canGoPrevious ? Theme.text : Theme.textDim
                                opacity: Media.canGoPrevious ? 1 : 0.45
                                font.family: Theme.font
                                font.pixelSize: 18

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: Media.canGoPrevious
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: Media.previous()
                                }
                            }

                            Text {
                                text: root.player?.isPlaying ? "󰏤" : "󰐊"
                                color: Media.canTogglePlaying ? Theme.accent : Theme.textDim
                                opacity: Media.canTogglePlaying ? 1 : 0.45
                                font.family: Theme.font
                                font.pixelSize: 22

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: Media.canTogglePlaying
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: Media.togglePlaying()
                                }
                            }

                            Text {
                                text: "󰒭"
                                color: Media.canGoNext ? Theme.text : Theme.textDim
                                opacity: Media.canGoNext ? 1 : 0.45
                                font.family: Theme.font
                                font.pixelSize: 18

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: Media.canGoNext
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: Media.next()
                                }
                            }
                        }
                    }
                }

                // ---- Sesión ----
                Card {
                    width: parent.width
                    height: 64

                    Row {
                        anchors.centerIn: parent
                        spacing: 26

                        // [icon, label, color, comando]
                        Repeater {
                            model: [
                                { icon: "󰐥", label: "Apagar", color: "urgent", cmd: ["systemctl", "poweroff"] },
                                { icon: "󰜉", label: "Reiniciar", color: "purple", cmd: ["systemctl", "reboot"] },
                                { icon: "󰤄", label: "Suspender", color: "cyan", cmd: ["systemctl", "suspend"] },
                                { icon: "󰍁", label: "Bloquear", color: "accent", cmd: ["hyprlock"] },
                                { icon: "󰿅", label: "Salir", color: "warning", cmd: ["hyprctl", "dispatch", "exit"] }
                            ]

                            delegate: Column {
                                required property var modelData

                                spacing: 3

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.icon
                                    color: modelData.color === "urgent" ? Theme.urgent
                                         : modelData.color === "purple" ? Theme.purple
                                         : modelData.color === "cyan" ? Theme.cyan
                                         : modelData.color === "warning" ? Theme.warning
                                         : Theme.accent
                                    font.family: Theme.font
                                    font.pixelSize: 18

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Quickshell.execDetached(modelData.cmd)
                                    }
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.label
                                    color: Theme.textDim
                                    font.family: Theme.font
                                    font.pixelSize: 9
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
