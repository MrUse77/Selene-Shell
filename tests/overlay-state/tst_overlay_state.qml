import QtQuick
import QtTest
import "../../Services/OverlayState.js" as OverlayState

// Tests deterministas del reducer de estado de overlays interactivos.
// Se ejecutan con: QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/overlay-state -import .
TestCase {
    id: root
    name: "OverlayState"

    readonly property var screenA: ({ name: "DP-2" })
    readonly property var screenB: ({ name: "HDMI-A-1" })
    readonly property var screenC: ({ name: "eDP-1" })

    function closedState() {
        return OverlayState.makeState("", null);
    }

    function verifyState(result, expectedActiveKind, expectedScreen, expectedAccepted) {
        compare(result.state.activeKind, expectedActiveKind,
                "activeKind esperada " + expectedActiveKind + " fue " + result.state.activeKind);
        compare(result.state.targetScreen, expectedScreen,
                "targetScreen esperada " + expectedScreen + " fue " + result.state.targetScreen);
        compare(result.accepted, expectedAccepted,
                "accepted esperado " + expectedAccepted + " fue " + result.accepted);
    }

    function test_global_exclusivity() {
        let state = closedState();
        let r1 = OverlayState.reduce(state,
            { type: "open", kind: "launcher", origin: { source: "widget", screen: screenA, explicit: true } },
            [screenA, screenB], {});
        verifyState(r1, "launcher", screenA, true);

        let r2 = OverlayState.reduce(r1.state,
            { type: "open", kind: "dashboard", origin: { source: "widget", screen: screenB, explicit: true } },
            [screenA, screenB], {});
        verifyState(r2, "dashboard", screenB, true);
    }

    function test_open_same_kind_idempotent() {
        let state = OverlayState.makeState("launcher", screenA);
        let r = OverlayState.reduce(state,
            { type: "open", kind: "launcher", origin: { source: "ipc", screen: screenB, explicit: true } },
            [screenA, screenB], {});
        verifyState(r, "launcher", screenA, true);
    }

    function test_toggle_closes_and_double_toggle_restores() {
        let state = closedState();
        let r1 = OverlayState.reduce(state,
            { type: "toggle", kind: "launcher", origin: { source: "widget", screen: screenA, explicit: true } },
            [screenA], {});
        verifyState(r1, "launcher", screenA, true);

        let r2 = OverlayState.reduce(r1.state,
            { type: "toggle", kind: "launcher", origin: { source: "widget", screen: screenA, explicit: true } },
            [screenA], {});
        verifyState(r2, "", null, true);
    }

    function test_capture_is_immutable() {
        let state = OverlayState.makeState("launcher", screenA);
        let r = OverlayState.reduce(state,
            { type: "noop", kind: "launcher", origin: { source: "ipc", screen: screenB, explicit: true } },
            [screenA, screenB], {});
        verifyState(r, "launcher", screenA, false);
    }

    function test_close_idempotent() {
        let state = closedState();
        let r1 = OverlayState.reduce(state,
            { type: "close", kind: "" },
            [], {});
        verifyState(r1, "", null, true);

        let r2 = OverlayState.reduce(state,
            { type: "close", kind: "launcher" },
            [], {});
        verifyState(r2, "", null, true);
    }

    function test_origin_removed_screen_rejected() {
        let state = OverlayState.makeState("launcher", screenA);
        let r = OverlayState.reduce(state,
            { type: "open", kind: "launcher", origin: { source: "widget", screen: screenA, explicit: true } },
            [screenB], {});
        verifyState(r, "", null, false);
    }

    function test_ipc_valid_origin_during_hotplug() {
        let state = OverlayState.makeState("launcher", screenA);
        let r = OverlayState.reduce(state,
            { type: "toggle", kind: "launcher", origin: { source: "ipc", screen: screenB, explicit: true } },
            [screenB], {});
        verifyState(r, "launcher", screenB, true);
    }

    function test_widget_origin_removed_screen_rejected() {
        let state = OverlayState.makeState("launcher", screenA);
        let r = OverlayState.reduce(state,
            { type: "open", kind: "launcher", origin: { source: "widget", screen: screenA, explicit: true } },
            [screenB], {});
        verifyState(r, "", null, false);
    }

    function test_fallback_no_screens() {
        let focused = OverlayState.resolveFocusedScreen("DP-2", []);
        compare(focused, null);

        let r = OverlayState.reduce(closedState(),
            { type: "open", kind: "launcher", origin: { source: "ipc", screen: null, explicit: true } },
            [], {});
        verifyState(r, "", null, false);
    }

    function test_close_for_screen() {
        let state = OverlayState.makeState("launcher", screenA);
        let r1 = OverlayState.reduce(state,
            { type: "closeForScreen", kind: "", screen: screenA },
            [screenA, screenB], {});
        verifyState(r1, "", null, true);

        let state2 = OverlayState.makeState("launcher", screenA);
        let r2 = OverlayState.reduce(state2,
            { type: "closeForScreen", kind: "", screen: screenB },
            [screenA, screenB], {});
        verifyState(r2, "launcher", screenA, true);
    }

    function test_fullscreen_policy() {
        let fs = {};
        fs[screenA.name] = true;
        let r1 = OverlayState.reduce(closedState(),
            { type: "open", kind: "launcher", origin: { source: "passive", screen: screenA, explicit: false } },
            [screenA], fs);
        verifyState(r1, "", null, false);

        let r2 = OverlayState.reduce(closedState(),
            { type: "open", kind: "launcher", origin: { source: "widget", screen: screenA, explicit: true } },
            [screenA], fs);
        verifyState(r2, "launcher", screenA, true);
    }

    function test_fast_sequence() {
        let state = closedState();
        let r1 = OverlayState.reduce(state,
            { type: "open", kind: "launcher", origin: { source: "widget", screen: screenA, explicit: true } },
            [screenA, screenB, screenC], {});
        let r2 = OverlayState.reduce(r1.state,
            { type: "open", kind: "dashboard", origin: { source: "widget", screen: screenB, explicit: true } },
            [screenA, screenB, screenC], {});
        let r3 = OverlayState.reduce(r2.state,
            { type: "open", kind: "power", origin: { source: "widget", screen: screenC, explicit: true } },
            [screenA, screenB, screenC], {});
        verifyState(r3, "power", screenC, true);
    }

    function test_invalid_kind_rejected() {
        let r = OverlayState.reduce(closedState(),
            { type: "open", kind: "calendar", origin: { source: "widget", screen: screenA, explicit: true } },
            [screenA], {});
        verifyState(r, "", null, false);
    }
}
