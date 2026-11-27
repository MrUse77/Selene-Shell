pragma Singleton

import QtQuick
import Quickshell.Services.Pipewire
import "AudioDeviceLogic.js" as AudioDeviceLogic

// Volumen del sink por defecto vía PipeWire. Reactivo: cualquier cambio
// (teclas, pavucontrol, dashboard) se refleja acá y dispara el OSD.
Item {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink

    property real volume: sink?.audio?.volume ?? 0
    property bool muted: sink?.audio?.muted ?? false

    readonly property int percent: Math.round(volume * 100)

    // Filas del selector de dispositivo: los sinks de hardware, con la marca
    // del que WirePlumber tiene como preferido. Se recalcula cuando PipeWire
    // agrega o quita nodos (`values` notifica).
    // Falso positivo: UntypedObjectModel.values existe en runtime pero
    // Quickshell no lo declara en sus .qmltypes.
    // qmllint disable missing-property
    readonly property var sinks: AudioDeviceLogic.sinkEntries(
        Pipewire.nodes.values,
        Pipewire.preferredDefaultAudioSink ?? Pipewire.defaultAudioSink)
    // qmllint enable missing-property

    // Las propiedades de audio son inválidas sin este tracker (requisito
    // documentado de PwNodeAudio).
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    // La preferencia (no el default efectivo) es lo que persiste entre
    // reinicios: la escribe WirePlumber y PipeWire la aplica al arrancar.
    function selectSink(node) {
        if (node) Pipewire.preferredDefaultAudioSink = node;
    }

    function setVolume(v) {
        const a = sink?.audio;
        if (a) a.volume = Math.max(0, Math.min(1.5, v));
    }

    function stepVolume(delta) {
        setVolume(volume + delta / 100);
    }

    function toggleMute() {
        const a = sink?.audio;
        if (a) a.muted = !a.muted;
    }
}
