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

    readonly property string activeKind: _activeKind
    readonly property var targetScreen: _targetScreen
    readonly property bool isOpen: _activeKind !== ""
    readonly property bool launcherOpen: _activeKind === "launcher"
    readonly property bool dashboardOpen: _activeKind === "dashboard"
    readonly property bool powerOpen: _activeKind === "power"
    readonly property string targetScreenName: _targetScreen?.name ?? ""

    // Cierra el overlay si la pantalla capturada deja de existir.
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (_targetScreen !== null && !root.isScreenValid(_targetScreen)) {
                root.closeForScreen(_targetScreen);
            }
        }
    }

    function open(kind, origin) {
        const result = OverlayState.reduce(
            { activeKind: _activeKind, targetScreen: _targetScreen },
            { type: "open", kind: kind, origin: origin },
            Quickshell.screens,
            fullscreenByScreen()
        );
        apply(result);
        return result.accepted;
    }

    function toggle(kind, origin) {
        const result = OverlayState.reduce(
            { activeKind: _activeKind, targetScreen: _targetScreen },
            { type: "toggle", kind: kind, origin: origin },
            Quickshell.screens,
            fullscreenByScreen()
        );
        apply(result);
        return result.accepted;
    }

    function close(kind) {
        const result = OverlayState.reduce(
            { activeKind: _activeKind, targetScreen: _targetScreen },
            { type: "close", kind: kind || "" },
            Quickshell.screens,
            {}
        );
        apply(result);
        return result.accepted;
    }

    function closeForScreen(screen) {
        const result = OverlayState.reduce(
            { activeKind: _activeKind, targetScreen: _targetScreen },
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
        if (nextKind === "") {
            _activeKind = "";
            _targetScreen = null;
        } else {
            _activeKind = "";
            _targetScreen = nextScreen;
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
