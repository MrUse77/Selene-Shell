// Resolución pura de la geometría declarada de la barra (alto y márgenes).
//
// Este módulo no importa nada: ni singletons, ni Quickshell, ni shell.json. La
// resolución y la validación viven acá justamente para que qmltestrunner las
// cubra sin levantar la shell. Un valor de geometría llega como string (de una
// variable de entorno o de shell.json) y puede ser cualquier basura, así que
// todo lo que entra pasa por resolve() antes de tocar el layout.

// El elemento fijo más alto de la barra mide 34 (Modules/Bar/Workspaces.qml
// `implicitHeight: 34`): una barra más baja recorta contenido, así que 34 es el
// piso real y no un número elegido al azar.
const MIN_BAR_HEIGHT = 34;
const MAX_BAR_HEIGHT = 96;
const MIN_MARGIN = 0;
const MAX_MARGIN = 200;

// Devuelve un entero acotado a [min, max] a partir de `raw`, o `fallback` si
// `raw` no es un entero representable.
//
// Acepta string o number. A los strings se les quita el espacio de alrededor:
// una env definida como SHELL_BAR_HEIGHT=" 44 " vale 44. Devuelven `fallback`
// los strings vacíos o con solo espacios, los valores que no son ni string ni
// number (null, undefined, booleanos, objetos), NaN, Infinity y los no enteros
// ("44.5", "abc"): en todos esos casos el valor no es confiable y gana el
// default. Un entero negativo cae en `min` por el mismo clamp que usa el resto
// de la casa — Math.min(Math.max(n, min), max) —, no por un caso especial.
function resolve(raw, fallback, min, max) {
    const value = typeof raw === "string" ? raw.trim() : raw;
    if (typeof value !== "string" && typeof value !== "number") return fallback;
    if (value === "") return fallback;
    const n = Number(value);
    if (!Number.isInteger(n)) return fallback;
    return Math.min(Math.max(n, min), max);
}

// Distancia del borde superior del monitor al borde superior de un panel que
// flota debajo de la barra: la geometría declarada de la barra más el gap de
// diseño del consumidor.
//
// No acota: los dos primeros sumandos ya pasaron por resolve() y el gap es una
// constante de diseño del módulo consumidor, así que la suma no puede salirse
// de rango por un valor crudo.
function panelTop(marginTop, barHeight, gap) {
    return marginTop + barHeight + gap;
}

// Margen derecho de un panel alineado a la derecha: el margen lateral declarado
// más el inset de diseño del consumidor.
//
// No acota, por lo mismo que panelTop: ambos sumandos ya son valores confiables
// (declarados o constantes de diseño), no crudos.
function panelRight(marginSide, inset) {
    return marginSide + inset;
}
