import QtQuick
import Quickshell.Services.Mpris
import "../../Services"
import "../../Components"

// Chip de medios: aparece solo cuando hay reproducción; abre el dashboard.
BarWidget {
    id: root

    property var screen: null

    hoverable: true

    readonly property var player: Mpris.activePlayer
    readonly property bool hasMedia: player != null && player.trackTitle !== ""

    visible: hasMedia
    height: 32
    width: hasMedia ? Math.min(220, row.implicitWidth + 18) : 0

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.player?.isPlaying ? "󰐊" : "󰐌"
            color: Theme.accent
            font.family: Theme.font
            font.pixelSize: 13
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 150
            text: root.player?.trackTitle ?? ""
            elide: Text.ElideRight
            color: Theme.textDim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            OverlayCoordinator.open("dashboard", {
                source: "widget",
                screen: root.screen,
                explicit: true
            });
        }
    }
}
