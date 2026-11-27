.pragma library

// Proyección pura de nodos PipeWire a filas del selector de dispositivo de
// audio. No depende de Quickshell: recibe objetos con la forma de PwNode, así
// que puede probarse sin un servidor PipeWire.

// Un nodo entra al selector sólo si es un sink de hardware. Los streams
// (reproducciones de aplicaciones) y los sources (micrófonos) quedan afuera:
// elegirlos como sink por defecto no tiene sentido y ensuciaría la lista.
function isSelectableSink(node) {
    return !!node && node.isSink === true && node.isStream !== true;
}

// Etiqueta principal: el nombre que el usuario reconoce. `nickname` es el que
// elige WirePlumber para mostrar, `description` es el del hardware y `name` la
// identidad técnica de ALSA/PipeWire. El literal final evita filas vacías.
function sinkLabel(node) {
    if (!node) return "Unknown";
    const candidates = [node.nickname, node.description, node.name];
    for (let i = 0; i < candidates.length; i++) {
        const value = candidates[i];
        if (typeof value === "string" && value !== "") return value;
    }
    return "Unknown";
}

// Línea secundaria: el primer identificador que no repita la etiqueta, para que
// una fila nunca muestre el mismo texto dos veces. Puede quedar vacía.
function sinkDetail(node) {
    if (!node) return "";
    const label = sinkLabel(node);
    const candidates = [node.description, node.name];
    for (let i = 0; i < candidates.length; i++) {
        const value = candidates[i];
        if (typeof value === "string" && value !== "" && value !== label) return value;
    }
    return "";
}

// Filas del selector, en el orden en que PipeWire entrega los nodos. La marca
// de default se resuelve por `id`: el PwNode del sink configurado puede ser otra
// instancia que la del listado, así que comparar identidad no sirve.
function sinkEntries(nodes, defaultSink) {
    const count = nodes && typeof nodes.length === "number" ? nodes.length : 0;
    const defaultId = defaultSink ? defaultSink.id : undefined;
    const entries = [];
    for (let i = 0; i < count; i++) {
        const node = nodes[i];
        if (!isSelectableSink(node)) continue;
        entries.push({
            id: node.id,
            node: node,
            label: sinkLabel(node),
            detail: sinkDetail(node),
            isDefault: defaultId !== undefined && defaultId !== null && node.id === defaultId
        });
    }
    return entries;
}
