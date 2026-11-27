import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../Services"
import "../../Components"

// Selector de dispositivo de audio bajo el indicador de volumen. El contenido
// vive en Components/AudioPanel.qml, compartido con el dashboard; acá queda la
// superficie: posición, foco y navegación por teclado.
// Elegir una fila fija el sink por defecto en WirePlumber, que lo recuerda
// entre reinicios; el volumen, la rueda y el OSD siguen leyendo `Audio.sink`.
PanelWindow {

    // Capa Overlay: por encima de las ventanas, incluso fullscreen
    WlrLayershell.layer: WlrLayer.Overlay
    // Sin zona exclusiva: flota sobre las ventanas, no les roba lugar
    exclusionMode: ExclusionMode.Ignore
    id: root

    property var modelData
    readonly property string screenName: modelData?.name ?? ""

    screen: modelData
    visible: ShellState.audioPickerOpen && ShellState.audioPickerScreen === screenName
    anchors {
        top: true
        left: true
    }
    // El popup se centra en el número de volumen: ShellState guarda el centro
    // del indicador (en coordenadas de pantalla) al abrirlo. Se acota para que
    // nunca salga de la pantalla en ninguno de los dos bordes.
    readonly property int gapBelowBar: 4
    readonly property int edgeInset: 8
    readonly property real centerX: ShellState.audioPickerCenterX
    // Falso positivo: QuickshellScreenInfo.width existe en runtime pero
    // Quickshell no lo declara en sus .qmltypes.
    // qmllint disable missing-property
    readonly property real screenWidth: screen ? screen.width : 0
    // qmllint enable missing-property
    readonly property int leftMargin: {
        const desired = centerX - implicitWidth / 2;
        const maxLeft = screenWidth - implicitWidth - edgeInset;
        return Math.round(Math.max(edgeInset, Math.min(maxLeft, desired)));
    }
    // Falso positivo: PanelWindow.margins existe en runtime pero Quickshell no
    // lo declara en sus .qmltypes.
    // qmllint disable missing-property
    margins {
        top: Geometry.panelTop(gapBelowBar)
        left: leftMargin
    }
    // qmllint enable missing-property
    implicitWidth: panel.implicitWidth
    implicitHeight: panel.implicitHeight
    color: "transparent"
    aboveWindows: true

    focusable: ShellState.audioPickerOpen

    // Fila resaltada por teclado; -1 = ninguna (solo puntero).
    property int selectedIndex: -1
    readonly property var entries: Audio.sinks

    function resetSelection() {
        selectedIndex = entries.length > 0 ? 0 : -1;
        for (let i = 0; i < entries.length; i++) {
            if (entries[i].isDefault) {
                selectedIndex = i;
                break;
            }
        }
    }

    function moveSelection(delta) {
        if (entries.length === 0) return;
        selectedIndex = (selectedIndex + delta + entries.length) % entries.length;
    }

    function applySelection() {
        const entry = entries[selectedIndex];
        if (!entry) return;
        Audio.selectSink(entry.node);
        ShellState.audioPickerOpen = false;
    }

    onVisibleChanged: {
        if (visible) {
            resetSelection();
            keyCatcher.forceActiveFocus();
        }
    }

    // Keys solo se adjunta a Items; en la raíz (PanelWindow) el attach falla
    // con WARN y la navegación queda muerta. Vive acá, enfocado.
    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.onUpPressed: root.moveSelection(-1)
        Keys.onDownPressed: root.moveSelection(1)
        Keys.onReturnPressed: root.applySelection()
        Keys.onEnterPressed: root.applySelection()
        Keys.onLeftPressed: Audio.stepVolume(-5)
        Keys.onRightPressed: Audio.stepVolume(5)
        Keys.onEscapePressed: ShellState.audioPickerOpen = false
        Keys.onPressed: event => {
            if (event.text.toLowerCase() === "m") {
                Audio.toggleMute();
                event.accepted = true;
            }
        }
    }

    HyprlandFocusGrab {
        active: root.visible
        onCleared: ShellState.audioPickerOpen = false
    }

    Card {
        anchors.fill: parent

        AudioPanel {
            id: panel
            anchors.fill: parent
            selectedIndex: root.selectedIndex
            onDeviceChosen: ShellState.audioPickerOpen = false
        }
    }
}
