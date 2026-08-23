import QtQuick
import "../../Services"
import "../../Components"

// CPU / RAM / temperatura compactos con estados de alerta.
BarWidget {
    id: root

    readonly property color cpuColor:
        Hardware.cpu >= Hardware.cpuCrit ? Theme.urgent
        : Hardware.cpu >= Hardware.cpuWarn ? Theme.warning
        : Theme.textDim

    readonly property color ramColor:
        Hardware.ram >= Hardware.ramWarn ? Theme.warning : Theme.textDim

    readonly property bool hotTemp: Hardware.temp >= Hardware.tempWarn

    height: 32
    width: row.implicitWidth + 16

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰻠"
            color: root.cpuColor
            font.family: Theme.font
            font.pixelSize: 13
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "CPU " + Math.round(Hardware.cpu) + "%"
            color: root.cpuColor
            font.family: Theme.fontMono
            font.pixelSize: 12
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰍛"
            color: root.ramColor
            font.family: Theme.font
            font.pixelSize: 14
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "RAM " + Math.round(Hardware.ram) + "%"
            color: root.ramColor
            font.family: Theme.fontMono
            font.pixelSize: 12
        }

        Text {
            visible: root.hotTemp
            anchors.verticalCenter: parent.verticalCenter
            text: "󰔏 " + Math.round(Hardware.temp) + "°"
            color: Theme.urgent
            font.family: Theme.font
            font.pixelSize: 12
        }
    }
}
