pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Tema de Selene, derivado en runtime de la raíz de temas configurada.
//
// Raíz de temas configurable (primer valor no vacío de la cadena gana):
//   1. Variable de entorno neutra    SHELL_THEMES_ROOT
//   2. Alias de compatibilidad       MOONARCH_THEMES_ROOT
//   3. Setting themesRoot            del archivo de settings de la shell
//                                    (<Quickshell.shellDir>/shell.json)
//   4. Default                       $HOME/.local/share/moonarch/themes
//
// El default es moonarch (Selene es su shell), pero NO es un requisito:
// cualquier raíz con la estructura <raíz>/current/{ghostty.conf, waybar.css,
// quickshell.json opcional} funciona sin cambios de código. El valor crudo de
// `themeCommand` de ese mismo settings vive acá como settingsThemeCommand; la
// cadena completa del comando se resuelve en Launcher.qml (Launcher.themeSelector).
//
// Fuentes de la paleta (en orden de prioridad por token):
//   1. <raíz>/current/quickshell.json   (fragmento dedicado, OPCIONAL;
//      prioridad total sobre lo derivado)
//   2. <raíz>/current/waybar.css        (@define-color)
//   3. <raíz>/current/ghostty.conf      (palette 0-15, background, foreground,
//      selection-*)
//   4. Fallback Tokyo Night embebido (arranque garantizado).
//
// El symlink `current` se swapea atómicamente sin que cambie la ruta, así
// que los watchers de archivo no se disparan: se re-lee periódicamente
// (poll liviano) y hay IPC `theme-reload` para refresh instantáneo.
Item {
    id: root

    // Devuelve el primer argumento definido y no vacío; el último es el default.
    function pick() {
        for (let i = 0; i < arguments.length - 1; i++) {
            const value = arguments[i];
            if (typeof value === "string" && value !== "") return value;
        }
        return arguments[arguments.length - 1];
    }

    // ---- Settings de la shell (shell.json) ----
    // La lectura y el parseo del archivo viven en Services/Settings.qml; acá
    // solo se declaran las claves que la shell conoce y su tipo. Un valor
    // ausente o del tipo equivocado significa "usar el default". Claves
    // reconocidas: themesRoot, themeCommand, workspacesPerMonitor, tempSensor,
    // barHeight, barMarginTop, barMarginSide y osdMarginBottom.
    readonly property string settingsThemesRoot: Settings.str("themesRoot")

    readonly property string settingsThemeCommand: Settings.str("themeCommand")

    // Un setting numérico viaja como string para pasar limpio por pick(), que
    // solo acepta strings no vacíos; "" significa "usar el default". Si la
    // clave falta o no es un número, el string queda vacío y la cadena del
    // consumidor cae a su default.
    function _numSetting(key) {
        const n = Settings.num(key, undefined);
        return typeof n === "number" ? String(n) : "";
    }

    // Cantidad de workspaces por monitor (la valida el consumidor).
    readonly property string settingsWorkspacesPerMonitor: _numSetting("workspacesPerMonitor")

    // Geometría declarada de la barra (la valida y la acota Geometry).
    readonly property string settingsBarHeight: _numSetting("barHeight")

    readonly property string settingsBarMarginTop: _numSetting("barMarginTop")

    readonly property string settingsBarMarginSide: _numSetting("barMarginSide")

    // Margen inferior del OSD (el único valor nuevo declarable de #8).
    readonly property string settingsOsdMarginBottom: _numSetting("osdMarginBottom")

    // Nombre del sensor de temperatura (p.ej. "k10temp"); "" = autodetectar.
    readonly property string settingsTempSensor: Settings.str("tempSensor")

    readonly property string themesRoot: pick(
        Quickshell.env("SHELL_THEMES_ROOT"),
        Quickshell.env("MOONARCH_THEMES_ROOT"),
        settingsThemesRoot,
        Quickshell.env("HOME") + "/.local/share/moonarch/themes"
    )

    // Default del comando de temas (D1); la cadena completa vive en Launcher.qml.
    readonly property string defaultThemeCommand:
        Quickshell.env("HOME") + "/.local/bin/moonarch/theme-selector"

    // ---- Tokens derivados (hex strings; usar Theme.alpha() para alphas) ----
    readonly property string bg: _t.bg
    readonly property string bgDeep: _t.bgDeep
    readonly property string surface: _t.surface
    readonly property string surfaceBright: _t.surfaceBright
    readonly property string text: _t.text
    readonly property string textDim: _t.textDim
    readonly property string accent: _t.accent
    readonly property string urgent: _t.urgent
    readonly property string success: _t.success
    readonly property string warning: _t.warning
    readonly property string purple: _t.purple
    readonly property string cyan: _t.cyan
    readonly property string gray: _t.gray

    // ---- Identidad tipográfica (Nerd Font, ver config del sistema) ----
    readonly property string font: "Hack Nerd Font"
    readonly property string fontMono: "CaskaydiaMono Nerd Font"
    readonly property int fontSize: 13

    // ---- Radio de identidad lunar ----
    readonly property int rCard: 16
    readonly property int rInner: 10

    // Estado interno derivado (recreado al re-parsear)
    // Tokens internos de la paleta. Se declaran como inline component para que
    // el linter vea los miembros: tipando `_t` con QtObject genérico, cada acceso
    // `_t.bg` era un warning missing-property (y un typo real pasaría en silencio,
    // como ya pasó con Theme.settings). Los valores embebidos son el fallback
    // Tokyo Night de arranque; applyTheme() los sobrescribe al derivar.
    component ThemeTokens: QtObject {
        property string bg
        property string bgDeep
        property string surface
        property string surfaceBright
        property string text
        property string textDim
        property string accent
        property string urgent
        property string success
        property string warning
        property string purple
        property string cyan
        property string gray
    }

    readonly property ThemeTokens _t: ThemeTokens {
        bg: "#1a1b26"
        bgDeep: "#11111b"
        surface: "#24283b"
        surfaceBright: "#2b2f45"
        text: "#c0caf5"
        textDim: "#565f89"
        accent: "#7aa2f7"
        urgent: "#f7768e"
        success: "#9ece6a"
        warning: "#e0af68"
        purple: "#bb9af7"
        cyan: "#7dcfff"
        gray: "#414868"
    }

    property string _lastGhostty: ""
    property string _lastWaybar: ""

    // ---- Utilidades de color ----
    function alpha(hexStr, a) {
        const c = hexToRgba(hexStr);
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function mix(hexA, hexB, t) {
        const a = hexToRgba(hexA), b = hexToRgba(hexB);
        const mixc = x => a[x] + (b[x] - a[x]) * t;
        return "#" + [mixc("r"), mixc("g"), mixc("b")]
            .map(v => Math.round(clamp01(v) * 255).toString(16).padStart(2, "0"))
            .join("");
    }

    function clamp01(v) { return Math.max(0, Math.min(1, v)); }

    function hexToRgba(h) {
        if (!h) return { r: 0, g: 0, b: 0 };
        let s = h.trim().replace("#", "");
        if (s.length === 3)
            s = s.split("").map(c => c + c).join("");
        if (s.length !== 6) return { r: 0, g: 0, b: 0 };
        return {
            r: parseInt(s.slice(0, 2), 16) / 255,
            g: parseInt(s.slice(2, 4), 16) / 255,
            b: parseInt(s.slice(4, 6), 16) / 255
        };
    }

    // ---- Parseo de fragmentos moonarch ----
    function parseGhostty(txt) {
        const map = {};
        for (const line of txt.split("\n")) {
            const t = line.trim();
            if (!t || t.startsWith("#")) continue;
            const eq = t.indexOf("=");
            if (eq < 0) continue;
            const key = t.slice(0, eq).trim();
            const val = t.slice(eq + 1).trim();
            // Forma legada: `palette 5 = #RRGGBB` (el indice esta en la clave).
            // Se conserva porque un bundle no verificado podria usarla.
            const pm = key.match(/^palette\s+(\d+)$/);
            if (pm) {
                map["p" + Number(pm[1])] = val;
            } else if (key === "palette") {
                // Forma real de ghostty: `palette = 5=#F5C2E7`. El primer split
                // en "=" deja key="palette" y val="5=#F5C2E7"; el indice y el
                // color viven en el valor, no en la clave.
                const pv = val.match(/^(\d+)\s*=\s*(.+)$/);
                if (pv) map["p" + Number(pv[1])] = pv[2];
                else map[key] = val;
            } else {
                map[key] = val;
            }
        }
        return map;
    }

    function parseWaybar(txt) {
        const map = {};
        const re = /@define-color\s+([\w-]+)\s+(#[0-9a-fA-F]{3,8})/g;
        let m;
        while ((m = re.exec(txt)) !== null) map[m[1]] = m[2];
        return map;
    }

    function applyTheme(ghosttyTxt, waybarTxt) {
        const g = ghosttyTxt ? parseGhostty(ghosttyTxt) : {};
        const w = waybarTxt ? parseWaybar(waybarTxt) : {};

        const bg = w.bg_dark || g.background || _t.bg;
        const p8 = g.p8 || _t.gray;
        _t.bg = bg;
        _t.bgDeep = mix(bg, "#000000", 0.35);
        _t.surface = mix(bg, p8, 0.32);
        _t.surfaceBright = mix(bg, g.foreground || _t.text, 0.08);
        _t.text = w.text_main || g.foreground || g.p15 || _t.text;
        _t.textDim = mix(_t.text, bg, 0.48);
        _t.accent = w.accent_blue || g.p4 || _t.accent;
        _t.urgent = w.urgent_red || g.p1 || _t.urgent;
        _t.success = g.p2 || _t.success;
        _t.warning = g.p3 || _t.warning;
        _t.purple = g.p5 || _t.purple;
        _t.cyan = g.p6 || _t.cyan;
        _t.gray = p8;

        // Hook de integración oficial moonarch: un fragmento dedicado por
        // bundle (quickshell.json con nombres de token idénticos) tiene
        // prioridad total sobre la derivación y sigue siendo opcional (D5).
        // onLoadFailed lo deja sin efecto, sin ruido de log.
        if (_lastOverride) {
            for (const k in _lastOverride) {
                if (k in _t) _t[k] = _lastOverride[k];
            }
            console.log("[selene:theme] overrides de quickshell.json aplicados");
        }

        console.log("[selene:theme] paleta aplicada — bg", _t.bg, "accent", _t.accent);
    }

    property var _lastOverride: null

    // Agrupa las lecturas de los tres FileView: Qt.callLater coalesce las
    // llamadas repetidas dentro del mismo ciclo del event loop, así que un
    // cambio de bundle converge en una sola aplicación de paleta (tarea 3.2).
    function _requestApply() {
        Qt.callLater(_applyCached);
    }

    function _applyCached() {
        applyTheme(_lastGhostty, _lastWaybar);
    }

    function reloadTheme() {
        ghosttyView.reload();
        waybarView.reload();
        overrideView.reload();
    }

    // ---- Lectura de fragmentos (poll: el swap del symlink no dispara watchers) ----
    FileView {
        id: ghosttyView
        path: `${root.themesRoot}/current/ghostty.conf`
        watchChanges: false
        printErrors: false
        onLoaded: {
            const txt = text();
            if (txt !== root._lastGhostty) {
                root._lastGhostty = txt;
                root._requestApply();
            }
        }
        onLoadFailed: Qt.callLater(() => root.applyTheme("", root._lastWaybar))
        Component.onCompleted: reload()
    }

    FileView {
        id: waybarView
        path: `${root.themesRoot}/current/waybar.css`
        watchChanges: false
        printErrors: false
        onLoaded: {
            const txt = text();
            if (txt !== root._lastWaybar) {
                root._lastWaybar = txt;
                root._requestApply();
            }
        }
        onLoadFailed: Qt.callLater(() => root.applyTheme(root._lastGhostty, ""))
        Component.onCompleted: reload()
    }

    // Fragmento dedicado (opcional, D5): quickshell.json por bundle.
    FileView {
        id: overrideView
        path: `${root.themesRoot}/current/quickshell.json`
        watchChanges: false
        printErrors: false
        onLoaded: {
            try {
                root._lastOverride = JSON.parse(text());
            } catch (e) {
                root._lastOverride = null;
            }
            root._requestApply();
        }
        onLoadFailed: {
            if (root._lastOverride !== null) {
                root._lastOverride = null;
                root._requestApply();
            }
        }
        Component.onCompleted: reload()
    }

    // Poll liviano: compara el texto; solo re-deriva si cambió el bundle.
    // 1 s: reload() es asincrónico y el primer ciclo tras el swap puede
    // re-leer contenido viejo — con 1 s el re-tema se percibe inmediato.
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            ghosttyView.reload();
            waybarView.reload();
            overrideView.reload();
        }
    }

    Component.onCompleted: applyTheme("", "")
}
