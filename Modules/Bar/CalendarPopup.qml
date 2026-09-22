import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../Services"
import "../../Components"

// Calendario lunar bajo el reloj. HyprlandFocusGrab lo cierra al hacer
// clic fuera — integración nativa con el compositor.
PanelWindow {

    // Capa Overlay: por encima de las ventanas, incluso fullscreen
    WlrLayershell.layer: WlrLayer.Overlay
    // Sin zona exclusiva: flota sobre las ventanas, no les roba lugar
    exclusionMode: ExclusionMode.Ignore
    id: root

    property var modelData
    readonly property string screenName: modelData?.name ?? ""

    screen: modelData
    visible: ShellState.calendarOpen && ShellState.calendarScreen === screenName
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
    implicitWidth: 320
    implicitHeight: 350
    color: "transparent"
    aboveWindows: true
    property int navMonth: 0
    property int navYear: 0

    // Navegación por teclado: ←/→ cambian mes, Esc cierra
    focusable: ShellState.calendarOpen

    onVisibleChanged: {
        if (visible) {
            const now = new Date();
            navMonth = now.getMonth();
            navYear = now.getFullYear();
            forceActiveFocus();
        }
    }

    // Keys solo se adjunta a Items; en la raíz (PanelWindow) el attach
    // falla con WARN y la navegación queda muerta. Vive acá, enfocado.
    Item {
        anchors.fill: parent
        focus: true

        Keys.onLeftPressed: navBack()
        Keys.onRightPressed: navForward()
        Keys.onEscapePressed: ShellState.calendarOpen = false
    }

    HyprlandFocusGrab {
        active: root.visible
        onCleared: ShellState.calendarOpen = false
    }

    Card {
        anchors.fill: parent

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 6

            // Navegación de mes
            Item {
                width: parent.width
                height: 32

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰅃"
                    color: Theme.textDim
                    font.family: Theme.font
                    font.pixelSize: 14

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.navBack()
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.monthName() + " " + root.navYear
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰅁"
                    color: Theme.textDim
                    font.family: Theme.font
                    font.pixelSize: 14

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.navForward()
                    }
                }
            }

            Controls.MonthGrid {
                width: parent.width
                height: parent.height - 60

                month: root.navMonth
                year: root.navYear
                locale: Qt.locale("es_AR")

                delegate: Text {
                    required property var model
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: model.day
                    color: model.today ? Theme.urgent
                         : model.month === root.navMonth ? Theme.text
                         : Theme.textDim
                    font.family: root.isWeekend(model.date) ? Theme.fontMono : Theme.font
                    font.pixelSize: 12
                    font.bold: model.today
                }
            }
        }
    }

    function navBack() {
        if (navMonth === 0) { navMonth = 11; navYear--; }
        else navMonth--;
    }

    function navForward() {
        if (navMonth === 11) { navMonth = 0; navYear++; }
        else navMonth++;
    }

    function monthName() {
        const names = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
                       "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"];
        return names[navMonth];
    }

    function isWeekend(d) {
        const day = d.getDay();
        return day === 0 || day === 6;
    }
}
