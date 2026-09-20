//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "Services"
import "Modules/Bar"
import "Modules/Launcher"
import "Modules/Dashboard"
import "Modules/Notifications"
import "Modules/Osd"
import "Modules/PowerMenu"

// Selene — la shell de MoonArch.
// Entry point fino: monta módulos por monitor y overlays globales.
ShellRoot {
    settings.watchFiles: true

    Variants {
        model: Quickshell.screens

        Bar {}
    }

    Variants {
        model: Quickshell.screens

        CalendarPopup {}
    }

    Variants {
        model: Quickshell.screens

        HistoryPopup {}
    }

    Variants {
        model: Quickshell.screens
        Launcher {}
    }

    Variants {
        model: Quickshell.screens
        Dashboard {}
    }

    Notifications {}

    Osd {}

    Variants {
        model: Quickshell.screens
        PowerMenu {}
    }

    IpcHandler {
        target: "selene"

        function openApps() { OverlayCoordinator.openLauncher("apps", { source: "ipc", screen: OverlayCoordinator.resolveFocusedScreen(), explicit: true }); }
        function openWindows() { OverlayCoordinator.openLauncher("windows", { source: "ipc", screen: OverlayCoordinator.resolveFocusedScreen(), explicit: true }); }
        function openRun() { OverlayCoordinator.openLauncher("run", { source: "ipc", screen: OverlayCoordinator.resolveFocusedScreen(), explicit: true }); }
        function openThemes() { OverlayCoordinator.openLauncher("themes", { source: "ipc", screen: OverlayCoordinator.resolveFocusedScreen(), explicit: true }); }
        function toggleLauncher() { OverlayCoordinator.toggle("launcher", { source: "ipc", screen: OverlayCoordinator.resolveFocusedScreen(), explicit: true }); }
        function toggleDashboard() { OverlayCoordinator.toggle("dashboard", { source: "ipc", screen: OverlayCoordinator.resolveFocusedScreen(), explicit: true }); }
        function togglePower() { OverlayCoordinator.toggle("power", { source: "ipc", screen: OverlayCoordinator.resolveFocusedScreen(), explicit: true }); }
        function themeReload() { Theme.reloadTheme() }
        function dnd() { ShellState.dnd = !ShellState.dnd }
        function clearNotifs() { ShellState.clearHistory() }
        function toggleCalendar() {
            ShellState.toggleCalendar(Hyprland.focusedMonitor?.name ?? "")
        }
        function toggleHistory() {
            ShellState.toggleHistory(Hyprland.focusedMonitor?.name ?? "")
        }
        function calc(expr: string): string { return ShellState.evalExpr(expr) }
        function mediaPlayPause() { Media.togglePlaying() }
        function mediaNext() { Media.next() }
        function mediaPrev() { Media.previous() }
    }
}
