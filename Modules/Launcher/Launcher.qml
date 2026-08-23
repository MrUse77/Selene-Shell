import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import "../../Services"
import "../../Components"

// Launcher de Selene: búsqueda fuzzy + cálculo inline con "=".
// Apertura popin (overshot, como windowsIn del compositor).
PanelWindow {

    // Capa Overlay: por encima de las ventanas, incluso fullscreen
    WlrLayershell.layer: WlrLayer.Overlay
    // Sin zona exclusiva: flota sobre las ventanas, no les roba lugar
    exclusionMode: ExclusionMode.Ignore
    id: root

    property var modelData

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    color: Theme.alpha(Theme.bgDeep, 0.55)
    visible: OverlayCoordinator.launcherOpen && OverlayCoordinator.targetScreen === modelData
    focusable: OverlayCoordinator.launcherOpen && OverlayCoordinator.targetScreen === modelData

    property var results: []
    property int selected: 0

    readonly property bool calcMode: searchInput.text.startsWith("=")
    readonly property string calcResult: ShellState.evalExpr(searchInput.text.slice(1))

    onVisibleChanged: {
        if (visible) {
            searchInput.text = "";
            selected = 0;
            updateResults();
            searchInput.forceActiveFocus();
        }
    }

    function close() {
        OverlayCoordinator.close("launcher");
    }

    // Coincidencia fuzzy por subsecuencia con bonus de racha.
    function fuzzy(q, text) {
        if (!q) return 0.01;
        let ti = 0, score = 0, streak = 0;
        for (let i = 0; i < q.length; i++) {
            const idx = text.indexOf(q[i], ti);
            if (idx < 0) return 0;
            streak = idx === ti ? streak + 2 : 0;
            score += 1 + streak;
            ti = idx + 1;
        }
        return score;
    }

    function updateResults() {
        if (calcMode) {
            results = [];
            return;
        }
        const q = searchInput.text.trim().toLowerCase();
        const apps = DesktopEntries.applications.values;
        const scored = [];
        for (let i = 0; i < apps.length; i++) {
            const app = apps[i];
            const name = (app.name || "").toLowerCase();
            const comment = (app.comment || "").toLowerCase();
            let s = fuzzy(q, name) * 2 + fuzzy(q, comment) * 0.4;
            if (q && name.startsWith(q)) s += 10;
            if (s > 0) scored.push({ app: app, score: s });
        }
        scored.sort((a, b) => b.score - a.score);
        results = scored.slice(0, 9).map(x => x.app);
    }

    function accept() {
        if (calcMode) {
            if (calcResult !== "") {
                Quickshell.execDetached(["wl-copy", calcResult]);
                console.log("[selene:launcher] copiado:", calcResult);
            }
            close();
            return;
        }
        const app = results[selected];
        if (app) {
            app.execute();
            close();
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(620, (modelData?.width ?? 640) - 60)
        height: Math.min(520, (modelData?.height ?? 700) - 120)
        radius: Theme.rCard
        color: Theme.alpha(Theme.bg, 0.97)
        border.width: 1
        border.color: Theme.alpha(Theme.accent, 0.22)

        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.94

        Behavior on opacity {
            NumberAnimation { duration: Anim.fast; easing.bezierCurve: Anim.easeOutQuint }
        }
        Behavior on scale {
            NumberAnimation { duration: Anim.normal; easing.bezierCurve: Anim.overshot }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            // Búsqueda
            Row {
                width: parent.width
                spacing: 12

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰍉"
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: 18
                }

                TextInput {
                    id: searchInput
                    width: parent.width - 36
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 17
                    clip: true
                    focus: true

                    onTextChanged: {
                        root.selected = 0;
                        root.updateResults();
                    }
                    onAccepted: root.accept()

                    Keys.onEscapePressed: root.close()
                    Keys.onUpPressed: {
                        root.selected = Math.max(0, root.selected - 1);
                    }
                    Keys.onDownPressed: {
                        if (root.calcMode) return;
                        root.selected = Math.min(root.results.length - 1, root.selected + 1);
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.alpha(Theme.text, 0.08)
            }

            // Resultado del cálculo
            Item {
                visible: root.calcMode
                width: parent.width
                height: 70

                Text {
                    anchors.centerIn: parent
                    text: root.calcResult === "" ? "…" : "= " + root.calcResult
                    color: root.calcResult === "" ? Theme.textDim : Theme.success
                    font.family: Theme.fontMono
                    font.pixelSize: 26
                    font.bold: root.calcResult !== ""
                }
            }

            // Resultados de apps
            ListView {
                id: list
                visible: !root.calcMode
                width: parent.width
                height: parent.height - 130
                clip: true
                spacing: 4
                model: root.results

                delegate: Rectangle {
                    required property var modelData
                    readonly property int idx: index

                    width: list.width
                    height: 52
                    radius: Theme.rInner
                    color: idx === root.selected ? Theme.alpha(Theme.accent, 0.14) : "transparent"
                    border.width: idx === root.selected ? 1 : 0
                    border.color: Theme.alpha(Theme.accent, 0.35)

                    Behavior on color {
                        ColorAnimation { duration: Anim.fast; easing.bezierCurve: Anim.smooth }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        spacing: 12

                        IconImage {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            height: 30
                            source: modelData.icon ?? ""
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 60

                            Text {
                                width: parent.width
                                text: modelData.name ?? ""
                                elide: Text.ElideRight
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 14
                            }
                            Text {
                                visible: (modelData.comment ?? "") !== ""
                                width: parent.width
                                text: modelData.comment ?? ""
                                elide: Text.ElideRight
                                color: Theme.textDim
                                font.family: Theme.font
                                font.pixelSize: 11
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: root.selected = parent.idx
                        onClicked: {
                            root.selected = parent.idx;
                            root.accept();
                        }
                    }
                }
            }

            // Pista de teclado
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "↵ abrir · ↑↓ navegar · esc cerrar · = calcular"
                color: Theme.textDim
                font.family: Theme.font
                font.pixelSize: 10
            }
        }
    }
}
