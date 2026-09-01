import QtQuick
import Quickshell
import "../../Services"
import "../../Components"
import "."

// Reloj con fase lunar; clic abre el calendario de este monitor.
BarWidget {
    id: root

    property var screen

    hoverable: true
    active: ShellState.calendarOpen && ShellState.calendarScreen === (screen?.name ?? "")

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    height: 32
    width: row.implicitWidth + 18

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 9

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: 14
            font.bold: true
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: ShellState.toggleCalendar(screen?.name ?? "")
    }
}
