pragma Singleton

import QtQuick

// Estado global de Selene: overlays, DND, historial de notificaciones y
// badges. Ventana única de verdad para la barra, el IPC y los módulos.
Item {
    id: root

    // Overlays (se abren en el monitor enfocado)
    property bool launcherOpen: false
    property bool dashboardOpen: false
    property bool powerOpen: false

    // Calendario por barra
    property bool calendarOpen: false
    property string calendarScreen: ""

    // Historial de notificaciones por barra
    property bool historyOpen: false
    property string historyScreen: ""

    // Notificaciones
    property bool dnd: false
    property int unread: 0
    readonly property ListModel history: ListModel {}

    readonly property int historyCap: 20

    function toggleLauncher() { launcherOpen = !launcherOpen }
    function toggleDashboard() { dashboardOpen = !dashboardOpen }
    function togglePower() { powerOpen = !powerOpen }

    function toggleCalendar(screenName) {
        if (calendarOpen && calendarScreen === screenName) {
            calendarOpen = false;
        } else {
            calendarScreen = screenName;
            calendarOpen = true;
        }
    }

    function toggleHistory(screenName) {
        if (historyOpen && historyScreen === screenName) {
            historyOpen = false;
        } else {
            historyScreen = screenName;
            historyOpen = true;
        }
    }

    function addHistory(appName, summary, body, urgency) {
        history.insert(0, {
            app: appName ?? "",
            summary: summary ?? "",
            body: body ?? "",
            urgency: urgency ?? 1,
            time: Qt.formatDateTime(new Date(), "HH:mm")
        });
        if (history.count > historyCap) history.remove(history.count - 1);
        unread++;
    }

    function clearHistory() {
        history.clear();
        unread = 0;
    }

    // Evaluación aritmética del launcher ("=..." — la comparte el IPC
    // para poder probarla y para binds de calculadora). Tolerante al
    // "=" inicial: con o sin él.
    function evalExpr(expr) {
        expr = String(expr ?? "").trim();
        if (expr.startsWith("=")) expr = expr.slice(1).trim();
        if (expr === "" || !/^[\d\s+\-*/().,%]+$/.test(expr) || !/\d/.test(expr))
            return "";
        try {
            const val = Function(`"use strict"; return (${expr})`)();
            return (typeof val === "number" && isFinite(val)) ? String(val) : "";
        } catch (e) {
            return "";
        }
    }
}
