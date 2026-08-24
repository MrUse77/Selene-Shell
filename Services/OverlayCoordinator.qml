pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "OverlayState.js" as OverlayState

// Autoridad única para launcher, dashboard y menú de energía.
// Captura una ShellScreen al abrir, aplica exclusividad global y cierra
// automáticamente cuando la pantalla capturada desaparece.
Item {
    id: root

    // Detalles de implementación privados: sólo las funciones públicas de
    // este singleton los asignan. Los consumidores deben usar open/toggle/close.
    property string _activeKind: ""
    property var _targetScreen: null
    property string _launcherMode: "apps"
    property int _sessionGeneration: 0

    readonly property string activeKind: _activeKind
    readonly property var targetScreen: _targetScreen
    readonly property string launcherMode: _launcherMode
    readonly property int sessionGeneration: _sessionGeneration
    readonly property bool isOpen: _activeKind !== ""
    readonly property bool launcherOpen: _activeKind === "launcher"
    readonly property bool dashboardOpen: _activeKind === "dashboard"
    readonly property bool powerOpen: _activeKind === "power"
    readonly property string targetScreenName: _targetScreen?.name ?? ""

    // Cierra el overlay si la pantalla capturada deja de existir.
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (root._targetScreen !== null && !root.isScreenValid(root._targetScreen)) {
                root.closeForScreen(root._targetScreen);
            }
        }
    }

    function setLauncherMode(mode) {
        const nextMode = ["apps", "windows", "run", "themes"].includes(mode) ? mode : "apps";
        if (_launcherMode === nextMode) return false;
        _sessionGeneration = OverlayState.bumpGeneration(currentState()).generation;
        _launcherMode = nextMode;
        return true;
    }

    function openLauncher(mode, origin) {
        setLauncherMode(mode);
        return open("launcher", origin);
    }

    function currentState() {
        return {
            activeKind: _activeKind,
            targetScreen: _targetScreen,
            generation: _sessionGeneration
        };
    }

    function captureSession(kind, screen) {
        return {
            kind: kind,
            screen: screen,
            generation: _sessionGeneration
        };
    }

    function sessionMatches(kind, screen, generation) {
        return OverlayState.matchesSession(currentState(), kind, screen, generation);
    }

    function closeSession(kind, screen, generation) {
        if (!sessionMatches(kind, screen, generation)) return false;
        return close(kind);
    }

    function open(kind, origin) {
        const result = OverlayState.reduce(
            currentState(),
            { type: "open", kind: kind, origin: origin },
            Quickshell.screens,
            fullscreenByScreen()
        );
        apply(result);
        return result.accepted;
    }

    function toggle(kind, origin) {
        const result = OverlayState.reduce(
            currentState(),
            { type: "toggle", kind: kind, origin: origin },
            Quickshell.screens,
            fullscreenByScreen()
        );
        apply(result);
        return result.accepted;
    }

    function close(kind) {
        const result = OverlayState.reduce(
            currentState(),
            { type: "close", kind: kind || "" },
            Quickshell.screens,
            {}
        );
        apply(result);
        return result.accepted;
    }

    function closeForScreen(screen) {
        const result = OverlayState.reduce(
            currentState(),
            { type: "closeForScreen", kind: "", screen: screen },
            Quickshell.screens,
            {}
        );
        apply(result);
        return result.accepted;
    }

    function isScreenValid(screen) {
        return OverlayState.isScreenValid(screen, Quickshell.screens);
    }

    function resolveFocusedScreen() {
        return OverlayState.resolveFocusedScreen(
            Hyprland.focusedMonitor?.name ?? "",
            Quickshell.screens
        );
    }

    function apply(result) {
        const nextKind = result.state.activeKind;
        const nextScreen = result.state.targetScreen;
        const nextGeneration = result.state.generation;
        if (nextKind === "") {
            _activeKind = "";
            _targetScreen = null;
            _sessionGeneration = nextGeneration;
        } else {
            _activeKind = "";
            _targetScreen = nextScreen;
            _sessionGeneration = nextGeneration;
            _activeKind = nextKind;
        }
    }

    function fullscreenByScreen() {
        const map = {};
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            const s = screens[i];
            const fs = s?.workspace?.fullscreen ?? false;
            if (s?.name) map[s.name] = fs;
        }
        return map;
    }
}
