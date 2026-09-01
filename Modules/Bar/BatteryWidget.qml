import QtQuick
import "../../Services"
import "../../Components"

// Compact optional battery status. A hidden desktop battery consumes no row space.
BarWidget {
    id: root

    readonly property color bandColor:
        Battery.band === "cyan" ? Theme.cyan
        : Battery.band === "success" ? Theme.success
        : Battery.band === "urgent" ? Theme.urgent
        : Battery.band === "warning" ? Theme.warning
        : Battery.band === "accent" ? Theme.accent
        : Theme.textDim

    visible: Battery.available
    height: 32
    width: Battery.available ? row.implicitWidth + 16 : 0

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Battery.icon
            color: root.bandColor
            font.family: Theme.font
            font.pixelSize: 15
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Battery.hasPercentage ? Battery.roundedPercent + "%" : "—"
            color: Battery.hasPercentage ? Theme.text : Theme.textDim
            font.family: Theme.fontMono
            font.pixelSize: 12
            font.bold: true
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: Battery.charging
            text: "󰚥"
            color: Theme.cyan
            font.family: Theme.font
            font.pixelSize: 11
        }
    }
}
