pragma Singleton

import QtQuick
import Quickshell.Services.Pipewire

// Volumen del sink por defecto vía PipeWire. Reactivo: cualquier cambio
// (teclas, pavucontrol, dashboard) se refleja acá y dispara el OSD.
Item {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink

    property real volume: sink?.audio?.volume ?? 0
    property bool muted: sink?.audio?.muted ?? false

    readonly property int percent: Math.round(volume * 100)

    // Las propiedades de audio son inválidas sin este tracker (requisito
    // documentado de PwNodeAudio).
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
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
