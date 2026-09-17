pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../Services"
import "../../Services/OperationState.js" as OperationState
import "../../Components"

// Selene session overlay. Destructive actions require an explicit second step.
PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    property var modelData
    property int selected: 0
    property var pendingAction: null
    property string errorText: ""
    property var actionState: OperationState.idle()
    property var actionProcess: null
    readonly property bool operationBusy: OperationState.isBusy(actionState)
    readonly property var actions: [
        { icon: "󰍁", label: "Bloquear", color: "accent", confirm: false, cmd: ["hyprlock"] },
        { icon: "󰤄", label: "Suspender", color: "cyan", confirm: false, cmd: ["systemctl", "suspend"] },
        { icon: "󰿅", label: "Salir", color: "warning", confirm: true, cmd: ["hyprctl", "dispatch", "exit"] },
        { icon: "󰜉", label: "Reiniciar", color: "purple", confirm: true, cmd: ["systemctl", "reboot"] },
        { icon: "󰐥", label: "Apagar", color: "urgent", confirm: true, cmd: ["systemctl", "poweroff"] }
    ]

    screen: modelData
    anchors { top: true; left: true; right: true; bottom: true }
    color: Theme.alpha(Theme.bgDeep, 0.6)
    visible: OverlayCoordinator.powerOpen && OverlayCoordinator.targetScreen === modelData
    focusable: OverlayCoordinator.powerOpen && OverlayCoordinator.targetScreen === modelData

    onVisibleChanged: {
        if (visible) {
            selected = 0;
            pendingAction = null;
            if (!operationBusy) errorText = "";
            content.forceActiveFocus();
        }
    }

    function close() {
        OverlayCoordinator.close("power");
    }

    function currentSession() {
        return OverlayCoordinator.captureSession("power", modelData);
    }

    function processSessionMatches(process) {
        return OverlayCoordinator.sessionMatches(
            process.sessionKind,
            process.sessionScreen,
            process.sessionGeneration
        );
    }

    function closeProcessSession(process) {
        return OverlayCoordinator.closeSession(
            process.sessionKind,
            process.sessionScreen,
            process.sessionGeneration
        );
    }

    function reportProcessFailure(process, message) {
        if (processSessionMatches(process) && visible) {
            errorText = message;
            content.forceActiveFocus();
            return;
        }
        Quickshell.execDetached(["notify-send", "-a", "Selene", "Selene session action failed", message]);
    }

    function tint(colorName) {
        return colorName === "urgent" ? Theme.urgent
            : colorName === "purple" ? Theme.purple
            : colorName === "cyan" ? Theme.cyan
            : colorName === "warning" ? Theme.warning
            : Theme.accent;
    }

    function choose(action) {
        if (operationBusy) return;
        errorText = "";
        if (action.confirm) {
            pendingAction = action;
            confirmYes.forceActiveFocus();
        } else {
            execute(action);
        }
    }

    function execute(action) {
        if (!action || operationBusy) return;
        const launch = OperationState.begin(actionState);
        if (!launch.accepted) return;
        actionState = launch.state;
        pendingAction = null;
        errorText = "Running " + action.label + "…";
        const session = currentSession();
        const process = actionProcessComponent.createObject(root, {
            operationToken: launch.token,
            actionLabel: action.label,
            closeOnStarted: action.cmd[0] === "hyprlock",
            sessionKind: session.kind,
            sessionScreen: session.screen,
            sessionGeneration: session.generation
        });
        if (!process) {
            actionState = OperationState.finish(actionState, launch.token).state;
            errorText = "Unable to create the action process";
            content.forceActiveFocus();
            return;
        }
        actionProcess = process;
        actionStartupWatchdog.restart();
        // El tipado de qmllint sobre el retorno de createObject() es QObject y
        // marca exec como missing-property; es un falso positivo: el objeto
        // creado ES un Process (Quickshell.Io.Process) y expone exec().
        // qmllint disable missing-property
        process.exec(action.cmd);
        // qmllint enable missing-property
    }

    function actionStarted(process) {
        if (actionProcess !== process || process.operationToken !== actionState.active) return;
        const live = OperationState.started(actionState, process.operationToken);
        if (!live.accepted) return;
        process.startedSuccessfully = true;
        actionStartupWatchdog.stop();
        if (process.closeOnStarted) {
            actionState = OperationState.finish(live.state, process.operationToken).state;
            actionProcess = null;
            closeProcessSession(process);
        } else {
            actionState = live.state;
        }
    }

    function actionExited(process, exitCode) {
        if (!process.startedSuccessfully) return;
        if (process.closeOnStarted) {
            if (exitCode !== 0) {
                reportProcessFailure(
                    process,
                    process.failureText(process.actionLabel + " failed with exit code " + exitCode)
                );
            }
            return;
        }
        if (actionProcess !== process || process.operationToken !== actionState.active) return;
        actionStartupWatchdog.stop();
        actionState = OperationState.finish(actionState, process.operationToken).state;
        actionProcess = null;
        if (exitCode === 0) {
            closeProcessSession(process);
        } else {
            reportProcessFailure(
                process,
                process.failureText("Action failed with exit code " + exitCode)
            );
        }
    }

    Component {
        id: actionProcessComponent
        Process {
            id: processInstance
            required property int operationToken
            required property string actionLabel
            required property bool closeOnStarted
            required property string sessionKind
            required property var sessionScreen
            required property int sessionGeneration
            property bool startedSuccessfully: false
            stdout: StdioCollector { id: processOutput }
            stderr: StdioCollector { id: processError }
            function failureText(fallback) { return processError.text.trim() || processOutput.text.trim() || fallback; }
            onStarted: root.actionStarted(processInstance)
            onExited: exitCode => {
                root.actionExited(processInstance, exitCode);
                processInstance.destroy();
            }
        }
    }

    Timer {
        id: actionStartupWatchdog
        interval: 1000
        onTriggered: {
            const process = root.actionProcess;
            if (!process || process.operationToken !== root.actionState.active) return;
            const timeout = OperationState.startupTimeout(root.actionState, process.operationToken);
            if (!timeout.accepted) return;
            root.actionState = timeout.state;
            root.actionProcess = null;
            root.reportProcessFailure(
                process,
                process.failureText("Unable to start " + process.actionLabel)
            );
            process.running = false;
            process.destroy();
        }
    }

    MouseArea { anchors.fill: parent; onClicked: root.close() }

    Item {
        id: content
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: {
            if (root.pendingAction) {
                root.pendingAction = null;
                content.forceActiveFocus();
            } else root.close();
        }
        Keys.onLeftPressed: root.selected = Math.max(0, root.selected - 1)
        Keys.onRightPressed: root.selected = Math.min(root.actions.length - 1, root.selected + 1)
        Keys.onReturnPressed: root.choose(root.actions[root.selected])
        Keys.onEnterPressed: root.choose(root.actions[root.selected])

        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Anim.fast; easing.bezierCurve: Anim.easeOutQuint } }
        Behavior on scale { NumberAnimation { duration: Anim.normal; easing.bezierCurve: Anim.overshot } }

        Card {
            id: actionCard
            visible: root.pendingAction === null
            enabled: !root.operationBusy
            anchors.centerIn: parent
            width: Math.min(570, (root.modelData?.width ?? 640) - 50)
            height: 170

            MouseArea { anchors.fill: parent; onClicked: mouse => mouse.accepted = true }

            Column {
                anchors.centerIn: parent
                spacing: 24

                Row {
                    spacing: 18
                    Repeater {
                        model: root.actions
                        delegate: Capsule {
                            id: act
                            required property var modelData
                            required property int index
                            width: 90
                            height: 90
                            glow: act.index === root.selected
                            alphaBg: hover.hovered ? 0.96 : 0.88

                            Column {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: act.modelData.icon
                                    color: root.tint(act.modelData.color)
                                    font.family: Theme.font
                                    font.pixelSize: 26
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: act.modelData.label
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: 11
                                }
                            }
                            HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor; onHoveredChanged: { if (hovered) root.selected = act.index; } }
                            TapHandler { onTapped: root.choose(act.modelData) }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.errorText || "← → navigate · enter select · esc cancel"
                    color: root.errorText ? Theme.urgent : Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                }
            }
        }

        Card {
            visible: root.pendingAction !== null
            anchors.centerIn: parent
            width: Math.min(420, (root.modelData?.width ?? 500) - 50)
            height: 190

            MouseArea { anchors.fill: parent; onClicked: mouse => mouse.accepted = true }

            Column {
                anchors.centerIn: parent
                spacing: 22

                MoonDisc {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 34
                    height: 34
                    rimColor: Theme.alpha(root.pendingAction ? root.tint(root.pendingAction.color) : Theme.accent, 0.7)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.pendingAction ? "¿Confirmar " + root.pendingAction.label.toLowerCase() + "?" : ""
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 17
                    font.bold: true
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 14
                    Capsule {
                        id: confirmNo
                        width: 120
                        enabled: !root.operationBusy
                        height: 38
                        Text { anchors.centerIn: parent; text: "Cancelar"; color: Theme.text; font.family: Theme.font }
                        TapHandler { onTapped: { root.pendingAction = null; content.forceActiveFocus(); } }
                    }
                    Capsule {
                        id: confirmYes
                        width: 120
                        enabled: !root.operationBusy
                        height: 38
                        glow: true
                        focus: root.pendingAction !== null
                        Text { anchors.centerIn: parent; text: "Confirmar"; color: Theme.urgent; font.family: Theme.font; font.bold: true }
                        Keys.onEscapePressed: { root.pendingAction = null; content.forceActiveFocus(); }
                        Keys.onReturnPressed: root.execute(root.pendingAction)
                        Keys.onEnterPressed: root.execute(root.pendingAction)
                        TapHandler { onTapped: root.execute(root.pendingAction) }
                    }
                }
            }
        }
    }
}
