pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Lectura única de `shell.json`, el archivo de settings de la shell.
//
// Un solo lugar lee y valida el archivo: cada módulo pide la clave que necesita
// con el accesor tipado que corresponda. Una clave ausente, o con el tipo
// equivocado, significa "usar el default": el accesor devuelve el fallback.
//
// Este servicio aporta únicamente la capa "setting" del patrón. La cadena
// completa (env neutro → setting → default) vive en cada consumidor, que es
// quien conoce su default.
Item {
    id: root

    // Objeto parseado del archivo; null si falta, si el JSON es inválido o si
    // no es un objeto. Se llama `values` y no `data` porque `Item` ya declara
    // `data` (la lista de hijos) y el FileView intentaría asignarse ahí.
    property var values: null

    readonly property string path: `${Quickshell.shellDir}/shell.json`

    // Clave string no vacía; si no, el fallback.
    function str(key, fallback) {
        const value = values?.[key];
        return (typeof value === "string" && value !== "")
            ? value
            : (fallback ?? "");
    }

    // Clave numérica finita; si no, el fallback.
    function num(key, fallback) {
        const value = values?.[key];
        return (typeof value === "number" && isFinite(value)) ? value : fallback;
    }

    // Clave entera; si no, el fallback.
    function int(key, fallback) {
        const value = root.num(key, undefined);
        return (typeof value === "number" && Number.isInteger(value)) ? value : fallback;
    }

    function _load(txt) {
        if (!txt) {
            values = null;
            return;
        }
        try {
            const parsed = JSON.parse(txt);
            values = (parsed && typeof parsed === "object" && !Array.isArray(parsed)) ? parsed : null;
        } catch (e) {
            values = null;
        }
    }

    FileView {
        id: settingsView
        path: root.path
        watchChanges: true
        printErrors: false
        onLoaded: root._load(text())
        onLoadFailed: root._load("")
        Component.onCompleted: reload()
    }
}
