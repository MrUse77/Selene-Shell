import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "Services"
import "Components"
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

    Launcher {}

    Dashboard {}

    Notifications {}

    Osd {}

    PowerMenu {}

    IpcHandler {
        target: "selene"

        function toggleLauncher() { ShellState.toggleLauncher() }
        function toggleDashboard() { ShellState.toggleDashboard() }
        function togglePower() { ShellState.togglePower() }
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
    }
}
