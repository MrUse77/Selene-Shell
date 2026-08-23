pragma Singleton

import QtQuick

// Fase lunar real — la firma de Selene.
// Ciclo sinódico con época de luna nueva: 2000-01-06 18:14 UTC.
QtObject {
    id: root

    readonly property real synodic: 29.530588853
    readonly property real epochMs: Date.UTC(2000, 0, 6, 18, 14)

    // phase: 0 = nueva, 0.25 = cuarto creciente, 0.5 = llena, 0.75 = menguante
    property real phase: 0
    // fracción iluminada 0..1 (para discos/gauges)
    property real illumination: 0
    property string name: ""

    readonly property var names: [
        "Luna nueva", "Luna creciente", "Cuarto creciente", "Gibosa creciente",
        "Luna llena", "Gibosa menguante", "Cuarto menguante", "Luna menguante"
    ]

    function compute() {
        const days = (Date.now() - epochMs) / 86400000;
        const age = ((days % synodic) + synodic) % synodic;
        phase = age / synodic;
        illumination = (1 - Math.cos(2 * Math.PI * phase)) / 2;
        const idx = Math.floor((((phase + 1 / 16) % 1) * 8));
        name = names[idx];
    }

    // Refresco diario: la fase no cambia perceptiblemente en horas.
    property Timer refresher: Timer {
        interval: 6 * 3600 * 1000
        running: true
        repeat: true
        onTriggered: root.compute()
    }

    Component.onCompleted: compute()
}
