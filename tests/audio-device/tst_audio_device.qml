import QtQuick
import QtTest
import "../../Services/AudioDeviceLogic.js" as DeviceLogic

// Tests deterministas de la proyección de nodos PipeWire a filas del selector
// de dispositivo de audio.
// Se ejecutan con: QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/audio-device -import .
TestCase {
    id: root
    name: "AudioDeviceLogic"

    function sink(overrides) {
        return Object.assign({
            id: 1,
            isSink: true,
            isStream: false,
            nickname: "",
            description: "",
            name: "alsa_output.pci"
        }, overrides ?? {});
    }

    function test_only_sinks_are_selectable() {
        verify(DeviceLogic.isSelectableSink(sink({})), "un sink de hardware es seleccionable");
        verify(!DeviceLogic.isSelectableSink(sink({ isSink: false })), "un source no es seleccionable");
        verify(!DeviceLogic.isSelectableSink(sink({ isStream: true })), "un stream no es seleccionable");
        verify(!DeviceLogic.isSelectableSink(null), "null no es seleccionable");
        verify(!DeviceLogic.isSelectableSink(undefined), "undefined no es seleccionable");
    }

    function test_label_prefers_nickname_then_description_then_name() {
        compare(DeviceLogic.sinkLabel(sink({ nickname: "Parlantes", description: "Starship/Matisse" })),
                "Parlantes");
        compare(DeviceLogic.sinkLabel(sink({ nickname: "", description: "Starship/Matisse" })),
                "Starship/Matisse");
        compare(DeviceLogic.sinkLabel(sink({ nickname: "", description: "" })),
                "alsa_output.pci");
        compare(DeviceLogic.sinkLabel(sink({ nickname: "", description: "", name: "" })), "Unknown");
        compare(DeviceLogic.sinkLabel(null), "Unknown");
    }

    function test_detail_never_repeats_the_label() {
        compare(DeviceLogic.sinkDetail(sink({ nickname: "Parlantes", description: "Starship/Matisse" })),
                "Starship/Matisse");
        compare(DeviceLogic.sinkDetail(sink({ nickname: "Parlantes", description: "" })),
                "alsa_output.pci");
        compare(DeviceLogic.sinkDetail(sink({ nickname: "alsa_output.pci", description: "" })), "");
        compare(DeviceLogic.sinkDetail(sink({ nickname: "Parlantes", description: "Parlantes" })),
                "alsa_output.pci");
        compare(DeviceLogic.sinkDetail(null), "");
    }

    function test_entries_filter_streams_and_mark_the_default() {
        const nodes = [
            sink({ id: 1, nickname: "A", description: "a" }),
            sink({ id: 2, isSink: false, isStream: true, nickname: "Stream", description: "s" }),
            sink({ id: 3, nickname: "B", description: "b" })
        ];
        const entries = DeviceLogic.sinkEntries(nodes, sink({ id: 3 }));

        compare(entries.length, 2, "solo los sinks de hardware entran al selector");
        compare(entries[0].id, 1);
        compare(entries[0].isDefault, false);
        compare(entries[1].id, 3);
        compare(entries[1].isDefault, true);
    }

    function test_entries_tolerate_missing_input() {
        compare(DeviceLogic.sinkEntries([], null).length, 0);
        compare(DeviceLogic.sinkEntries(null, null).length, 0);
        compare(DeviceLogic.sinkEntries(undefined, undefined).length, 0);
    }

    function test_entries_survive_a_default_outside_the_list() {
        const entries = DeviceLogic.sinkEntries([sink({ id: 7 })], sink({ id: 99 }));
        compare(entries.length, 1);
        compare(entries[0].isDefault, false, "un default ausente no marca ninguna fila");
    }
}
