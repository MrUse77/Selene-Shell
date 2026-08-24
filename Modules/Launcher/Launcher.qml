pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import "../../Services"
import "../../Services/LauncherLogic.js" as LauncherLogic
import "../../Services/OperationState.js" as OperationState
import "../../Components"

// Unified Selene picker: applications, live windows, commands, themes and "=" calculator.
PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    property var modelData
    property string mode: "apps"
    property var results: []
    property var themes: []
    property int selected: 0
    property string statusText: ""
    property bool statusError: false
    property bool themesLoading: false
    property int themeLoadGeneration: 0
    property var commandState: OperationState.idle()
    property var themeLoadState: OperationState.idle()
    property var themeApplyState: OperationState.idle()
    property var commandProcess: null
    property var themeListProcess: null
    property var themeApplyProcess: null

    readonly property bool commandBusy: OperationState.isBusy(commandState)
    readonly property bool themeApplyBusy: OperationState.isBusy(themeApplyState)
    readonly property bool acceptanceBusy: commandBusy || themeApplyBusy || themesLoading
    readonly property string themeSelector: Quickshell.env("HOME") + "/.local/bin/moonarch/theme-selector"
    readonly property bool calcMode: searchInput.text.startsWith("=")
    readonly property string calcResult: ShellState.evalExpr(searchInput.text.slice(1))
    readonly property var modes: [
        { key: "apps", label: "Apps", icon: "󰀻" },
        { key: "windows", label: "Active Apps", icon: "󰖲" },
        { key: "run", label: "Run", icon: "󰆍" },
        { key: "themes", label: "Themes", icon: "󰏘" }
    ]

    screen: modelData
    anchors { top: true; left: true; right: true; bottom: true }
    color: Theme.alpha(Theme.bgDeep, 0.55)
    visible: OverlayCoordinator.launcherOpen && OverlayCoordinator.targetScreen === modelData
    focusable: OverlayCoordinator.launcherOpen && OverlayCoordinator.targetScreen === modelData

    onVisibleChanged: {
        if (visible) {
            setMode(OverlayCoordinator.launcherMode);
        } else {
            invalidateThemeLoad();
        }
    }

    Connections {
        target: OverlayCoordinator
        function onLauncherModeChanged() {
            if (root.visible) root.setMode(OverlayCoordinator.launcherMode);
        }
    }

    function close() {
        OverlayCoordinator.close("launcher");
    }

    function clearStatus() {
        statusText = "";
        statusError = false;
    }

    function setMode(nextMode) {
        const normalizedMode = LauncherLogic.normalizeMode(nextMode);
        if (visible && OverlayCoordinator.launcherMode !== normalizedMode) {
            OverlayCoordinator.setLauncherMode(normalizedMode);
            return;
        }
        if (mode === "themes") invalidateThemeLoad();
        mode = normalizedMode;
        searchInput.text = "";
        selected = 0;
        clearStatus();
        if (mode === "themes") loadThemes();
        else updateResults();
        searchInput.forceActiveFocus();
    }

    function cycleMode(delta) {
        setMode(LauncherLogic.cycleMode(mode, delta));
    }

    function itemTitle(item) {
        if (mode === "apps") return item?.name ?? "";
        return item?.title ?? "";
    }

    function itemSubtitle(item) {
        if (mode === "apps") return item?.comment ?? "";
        return item?.subtitle ?? "";
    }

    function itemIcon(item) {
        if (mode === "apps") return item?.icon ?? "";
        return item?.icon ?? "application-x-executable";
    }

    function updateResults() {
        if (calcMode || mode === "run") {
            results = [];
            return;
        }

        const q = searchInput.text.trim().toLowerCase();
        if (mode === "apps") {
            const apps = DesktopEntries.applications.values;
            const scored = [];
            for (let i = 0; i < apps.length; i++) {
                const app = apps[i];
                const name = (app.name || "").toLowerCase();
                const comment = (app.comment || "").toLowerCase();
                let s = LauncherLogic.fuzzyScore(q, name) * 2
                      + LauncherLogic.fuzzyScore(q, comment) * 0.4;
                if (s > 0) scored.push({ app: app, score: s });
            }
            scored.sort((a, b) => b.score - a.score);
            results = scored.map(x => x.app);
            return;
        }

        if (mode === "windows") {
            const windows = Hyprland.toplevels.values;
            const items = [];
            for (let i = 0; i < windows.length; i++) {
                const win = windows[i];
                const ipc = win.lastIpcObject || {};
                items.push({
                    title: win.title || ipc.class || "Untitled window",
                    subtitle: (ipc.class || "Application") + " · " + (win.workspace?.name || "workspace"),
                    icon: ipc.class || "application-x-executable",
                    window: win
                });
            }
            results = LauncherLogic.rankItems(q, items);
            return;
        }

        results = LauncherLogic.rankItems(q, themes);
    }

    function currentSession() {
        return OverlayCoordinator.captureSession("launcher", modelData);
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

    function reportProcessFailure(process, title, message) {
        if (processSessionMatches(process) && visible) {
            statusError = true;
            statusText = message;
            searchInput.forceActiveFocus();
            return;
        }
        Quickshell.execDetached(["notify-send", "-a", "Selene", title, message]);
    }

    function invalidateThemeLoad() {
        const process = themeListProcess;
        themeListStartupWatchdog.stop();
        if (process) {
            process.running = false;
            process.destroy();
        }
        if (OperationState.isBusy(themeLoadState)) {
            themeLoadState = OperationState.finish(themeLoadState, themeLoadState.active).state;
        }
        themeLoadGeneration = themeLoadState.generation;
        themeListProcess = null;
        themesLoading = false;
    }

    function loadThemes() {
        themes = [];
        results = [];
        themesLoading = true;
        clearStatus();
        statusText = "Loading validated MoonArch themes…";

        const launch = OperationState.begin(themeLoadState);
        if (!launch.accepted) return;
        themeLoadState = launch.state;
        themeLoadGeneration = launch.token;
        const session = currentSession();
        const process = themeListProcessComponent.createObject(root, {
            operationToken: launch.token,
            sessionKind: session.kind,
            sessionScreen: session.screen,
            sessionGeneration: session.generation
        });
        if (!process) {
            themeLoadState = OperationState.finish(themeLoadState, launch.token).state;
            themesLoading = false;
            statusError = true;
            statusText = "Unable to create the theme list process";
            return;
        }
        themeListProcess = process;
        themeListStartupWatchdog.restart();
        process.exec([themeSelector, "--list"]);
    }

    function runCommand() {
        if (commandBusy) return;
        const parsed = LauncherLogic.parseCommand(searchInput.text);
        if (!parsed.ok) {
            statusError = true;
            statusText = parsed.error;
            return;
        }

        const launch = OperationState.begin(commandState);
        if (!launch.accepted) return;
        commandState = launch.state;
        statusError = false;
        statusText = "Running " + parsed.args[0] + "…";
        const session = currentSession();
        const process = commandProcessComponent.createObject(root, {
            operationToken: launch.token,
            sessionKind: session.kind,
            sessionScreen: session.screen,
            sessionGeneration: session.generation
        });
        if (!process) {
            commandState = OperationState.finish(commandState, launch.token).state;
            statusError = true;
            statusText = "Unable to create the command process";
            return;
        }
        commandProcess = process;
        commandStartupWatchdog.restart();
        process.exec(parsed.args);
    }

    function applyTheme(item) {
        if (themeApplyBusy) return;
        const launch = OperationState.begin(themeApplyState);
        if (!launch.accepted) return;
        themeApplyState = launch.state;
        statusError = false;
        statusText = "Applying " + item.themeId + "…";
        const session = currentSession();
        const process = themeApplyProcessComponent.createObject(root, {
            operationToken: launch.token,
            sessionKind: session.kind,
            sessionScreen: session.screen,
            sessionGeneration: session.generation
        });
        if (!process) {
            themeApplyState = OperationState.finish(themeApplyState, launch.token).state;
            statusError = true;
            statusText = "Unable to create the theme apply process";
            return;
        }
        themeApplyProcess = process;
        themeApplyStartupWatchdog.restart();
        process.exec([themeSelector, "--apply", item.themeId]);
    }

    function accept() {
        if (acceptanceBusy) return;
        if (calcMode) {
            if (calcResult !== "") {
                Quickshell.execDetached(["wl-copy", calcResult]);
                console.log("[selene:launcher] copied calculator result");
                close();
            } else {
                statusError = true;
                statusText = "The calculator expression is invalid";
            }
            return;
        }

        if (mode === "run") {
            runCommand();
            return;
        }

        const item = results[selected];
        if (!item) return;
        if (mode === "apps") {
            item.execute();
            close();
        } else if (mode === "windows") {
            if (!item.window?.address) {
                statusError = true;
                statusText = "The selected window is no longer available";
                updateResults();
                return;
            }
            Hyprland.dispatch("focuswindow address:" + item.window.address);
            close();
        } else if (mode === "themes") {
            if (themesLoading) return;
            applyTheme(item);
        }
    }

    function commandStarted(process) {
        if (commandProcess !== process || process.operationToken !== commandState.active) return;
        const live = OperationState.started(commandState, process.operationToken);
        if (!live.accepted) return;
        process.startedSuccessfully = true;
        commandStartupWatchdog.stop();
        commandState = OperationState.finish(live.state, process.operationToken).state;
        commandProcess = null;
        closeProcessSession(process);
    }

    function commandExited(process, exitCode) {
        if (!process.startedSuccessfully) return;
        if (exitCode !== 0) {
            reportProcessFailure(
                process,
                "Selene command failed",
                process.failureText("Command failed with exit code " + exitCode)
            );
        }
    }

    function themeListStarted(process) {
        if (themeListProcess !== process || process.operationToken !== themeLoadGeneration) return;
        const live = OperationState.started(themeLoadState, process.operationToken);
        if (!live.accepted) return;
        themeLoadState = live.state;
        themeListStartupWatchdog.stop();
    }

    function themeListExited(process, exitCode) {
        if (themeListProcess !== process || process.operationToken !== themeLoadGeneration) return;
        themeListStartupWatchdog.stop();
        themeLoadState = OperationState.finish(themeLoadState, process.operationToken).state;
        themeListProcess = null;
        themesLoading = false;
        if (!processSessionMatches(process) || !visible || mode !== "themes") return;
        if (exitCode !== 0) {
            themes = [];
            results = [];
            statusError = true;
            statusText = process.failureText("Unable to list MoonArch themes");
            return;
        }
        const lines = process.outputText().split("\n").map(x => x.trim()).filter(x => x !== "");
        themes = lines.map(id => ({
            themeId: id,
            title: id.split("-").map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(" "),
            subtitle: id,
            icon: "preferences-desktop-theme"
        }));
        clearStatus();
        updateResults();
    }

    function themeApplyStarted(process) {
        if (themeApplyProcess !== process || process.operationToken !== themeApplyState.active) return;
        const live = OperationState.started(themeApplyState, process.operationToken);
        if (!live.accepted) return;
        themeApplyState = live.state;
        themeApplyStartupWatchdog.stop();
    }

    function themeApplyExited(process, exitCode) {
        if (themeApplyProcess !== process || process.operationToken !== themeApplyState.active) return;
        themeApplyStartupWatchdog.stop();
        themeApplyState = OperationState.finish(themeApplyState, process.operationToken).state;
        themeApplyProcess = null;
        if (exitCode === 0) {
            Theme.reloadTheme();
            closeProcessSession(process);
        } else {
            reportProcessFailure(
                process,
                "Selene theme apply failed",
                process.failureText("Theme apply failed; MoonArch restored the previous theme")
            );
        }
    }

    Component {
        id: commandProcessComponent
        Process {
            id: processInstance
            required property int operationToken
            required property string sessionKind
            required property var sessionScreen
            required property int sessionGeneration
            property bool startedSuccessfully: false
            stdout: StdioCollector { id: processOutput }
            stderr: StdioCollector { id: processError }
            function failureText(fallback) { return processError.text.trim() || processOutput.text.trim() || fallback; }
            onStarted: root.commandStarted(processInstance)
            onExited: exitCode => {
                root.commandExited(processInstance, exitCode);
                processInstance.destroy();
            }
        }
    }

    Component {
        id: themeListProcessComponent
        Process {
            id: processInstance
            required property int operationToken
            required property string sessionKind
            required property var sessionScreen
            required property int sessionGeneration
            stdout: StdioCollector { id: processOutput }
            stderr: StdioCollector { id: processError }
            function outputText() { return processOutput.text; }
            function failureText(fallback) { return processError.text.trim() || processOutput.text.trim() || fallback; }
            onStarted: root.themeListStarted(processInstance)
            onExited: exitCode => {
                root.themeListExited(processInstance, exitCode);
                processInstance.destroy();
            }
        }
    }

    Component {
        id: themeApplyProcessComponent
        Process {
            id: processInstance
            required property int operationToken
            required property string sessionKind
            required property var sessionScreen
            required property int sessionGeneration
            stdout: StdioCollector { id: processOutput }
            stderr: StdioCollector { id: processError }
            function failureText(fallback) { return processError.text.trim() || processOutput.text.trim() || fallback; }
            onStarted: root.themeApplyStarted(processInstance)
            onExited: exitCode => {
                root.themeApplyExited(processInstance, exitCode);
                processInstance.destroy();
            }
        }
    }

    Timer {
        id: commandStartupWatchdog
        interval: 1000
        onTriggered: {
            const process = root.commandProcess;
            if (!process || process.operationToken !== root.commandState.active) return;
            const timeout = OperationState.startupTimeout(root.commandState, process.operationToken);
            if (!timeout.accepted) return;
            root.commandState = timeout.state;
            root.commandProcess = null;
            root.reportProcessFailure(
                process,
                "Selene command failed",
                process.failureText("Unable to start command")
            );
            process.running = false;
            process.destroy();
        }
    }

    Timer {
        id: themeListStartupWatchdog
        interval: 1000
        onTriggered: {
            const process = root.themeListProcess;
            if (!process || process.operationToken !== root.themeLoadGeneration) return;
            const timeout = OperationState.startupTimeout(root.themeLoadState, process.operationToken);
            if (!timeout.accepted) return;
            root.themeLoadState = timeout.state;
            root.themeListProcess = null;
            root.themesLoading = false;
            root.reportProcessFailure(
                process,
                "Selene theme list failed",
                process.failureText("Unable to start the theme list process")
            );
            process.running = false;
            process.destroy();
        }
    }

    Timer {
        id: themeApplyStartupWatchdog
        interval: 1000
        onTriggered: {
            const process = root.themeApplyProcess;
            if (!process || process.operationToken !== root.themeApplyState.active) return;
            const timeout = OperationState.startupTimeout(root.themeApplyState, process.operationToken);
            if (!timeout.accepted) return;
            root.themeApplyState = timeout.state;
            root.themeApplyProcess = null;
            root.reportProcessFailure(
                process,
                "Selene theme apply failed",
                process.failureText("Unable to start the theme apply process")
            );
            process.running = false;
            process.destroy();
        }
    }

    Timer {
        interval: 400
        repeat: true
        running: root.visible && root.mode === "windows"
        onTriggered: root.updateResults()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Card {
        id: card
        anchors.centerIn: parent
        width: Math.min(680, (root.modelData?.width ?? 720) - 60)
        height: Math.min(560, (root.modelData?.height ?? 700) - 100)

        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: Anim.fast; easing.bezierCurve: Anim.easeOutQuint } }
        Behavior on scale { NumberAnimation { duration: Anim.normal; easing.bezierCurve: Anim.overshot } }

        MouseArea {
            anchors.fill: parent
            onClicked: mouse => mouse.accepted = true
        }

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            Row {
                width: parent.width
                spacing: 8

                Repeater {
                    model: root.modes
                    delegate: Capsule {
                        id: modeButton
                        required property var modelData
                        width: (card.width - 56) / 4
                        height: 34
                        enabled: !root.commandBusy && !root.themeApplyBusy
                        glow: root.mode === modelData.key
                        alphaBg: hover.hovered ? 0.98 : 0.86

                        Row {
                            anchors.centerIn: parent
                            height: parent.height
                            spacing: 6
                            Text {
                                height: parent.height
                                verticalAlignment: Text.AlignVCenter
                                text: modeButton.modelData.icon
                                color: root.mode === modeButton.modelData.key ? Theme.accent : Theme.textDim
                                font.family: Theme.font
                            }
                            Text {
                                height: parent.height
                                verticalAlignment: Text.AlignVCenter
                                text: modeButton.modelData.label
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 11
                            }
                        }
                        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.setMode(modeButton.modelData.key) }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 12

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.calcMode ? "󰃬" : root.modes.find(x => x.key === root.mode).icon
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
                    enabled: !root.acceptanceBusy

                    onTextChanged: {
                        root.selected = 0;
                        root.clearStatus();
                        root.updateResults();
                    }
                    onAccepted: root.accept()
                    Keys.onEscapePressed: root.close()
                    Keys.onUpPressed: root.selected = Math.max(0, root.selected - 1)
                    Keys.onDownPressed: {
                        if (!root.calcMode && root.mode !== "run")
                            root.selected = Math.min(root.results.length - 1, root.selected + 1);
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Tab) {
                            root.cycleMode(event.modifiers & Qt.ShiftModifier ? -1 : 1);
                            event.accepted = true;
                            return;
                        }
                        if (event.modifiers & Qt.ControlModifier && event.key >= Qt.Key_1 && event.key <= Qt.Key_4) {
                            root.setMode(root.modes[event.key - Qt.Key_1].key);
                            event.accepted = true;
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.alpha(Theme.text, 0.08) }

            Item {
                visible: root.calcMode
                width: parent.width
                height: 80
                Text {
                    anchors.centerIn: parent
                    text: root.calcResult === "" ? "Invalid expression" : "= " + root.calcResult
                    color: root.calcResult === "" ? Theme.urgent : Theme.success
                    font.family: Theme.fontMono
                    font.pixelSize: 26
                    font.bold: root.calcResult !== ""
                }
            }

            Item {
                visible: !root.calcMode && root.mode === "run"
                width: parent.width
                height: 80
                Text {
                    anchors.centerIn: parent
                    text: "Commands run directly without shell expansion, pipelines or redirection"
                    color: Theme.textDim
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }

            ListView {
                id: list
                visible: !root.calcMode && root.mode !== "run"
                width: parent.width
                height: parent.height - 160
                clip: true
                spacing: 2
                model: root.results
                currentIndex: root.selected
                onCurrentIndexChanged: {
                    if (currentIndex >= 0)
                        positionViewAtIndex(currentIndex, ListView.Contain);
                }

                delegate: Rectangle {
                    id: resultDelegate
                    required property var modelData
                    required property int index

                    width: list.width
                    enabled: !root.acceptanceBusy
                    height: 46
                    radius: Theme.rInner
                    color: resultDelegate.index === root.selected ? Theme.alpha(Theme.accent, 0.14) : "transparent"
                    border.width: resultDelegate.index === root.selected ? 1 : 0
                    border.color: Theme.alpha(Theme.accent, 0.35)
                    Behavior on color { ColorAnimation { duration: Anim.fast; easing.bezierCurve: Anim.smooth } }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        spacing: 12

                        IconImage {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            height: 30
                            source: Quickshell.iconPath(resultDelegate.modelData.icon ?? "", "application-x-executable")
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 60
                            Text {
                                width: parent.width
                                text: root.itemTitle(resultDelegate.modelData)
                                elide: Text.ElideRight
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 14
                            }
                            Text {
                                visible: root.itemSubtitle(resultDelegate.modelData) !== ""
                                width: parent.width
                                text: root.itemSubtitle(resultDelegate.modelData)
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
                        onPositionChanged: root.selected = resultDelegate.index
                        onClicked: {
                            root.selected = resultDelegate.index;
                            root.accept();
                        }
                    }
                }
            }

            Text {
                visible: root.statusText !== ""
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.statusText
                color: root.statusError ? Theme.urgent : Theme.textDim
                elide: Text.ElideRight
                font.family: Theme.fontMono
                font.pixelSize: 11
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "tab / ctrl+1…4 switch · ↵ select · ↑↓ navigate · esc close · = calculate"
                color: Theme.textDim
                font.family: Theme.font
                font.pixelSize: 10
            }
        }
    }
}
