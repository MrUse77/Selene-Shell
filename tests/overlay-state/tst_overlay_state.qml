import QtQuick
import QtTest
import "../../Services/OverlayState.js" as OverlayState
import "../../Services/LauncherLogic.js" as LauncherLogic
import "../../Services/OperationState.js" as OperationState
import "../../Services/MediaLogic.js" as MediaLogic

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

    function test_launcher_mode_normalization_and_cycle() {
        compare(LauncherLogic.normalizeMode("windows"), "windows");
        compare(LauncherLogic.normalizeMode("unknown"), "apps");
        compare(LauncherLogic.cycleMode("apps", 1), "windows");
        compare(LauncherLogic.cycleMode("apps", -1), "themes");
        compare(LauncherLogic.cycleMode("themes", 1), "apps");
    }

    function test_command_parser_preserves_argument_boundaries() {
        let simple = LauncherLogic.parseCommand("notify-send hello");
        compare(simple.ok, true);
        compare(simple.args.length, 2);
        compare(simple.args[0], "notify-send");
        compare(simple.args[1], "hello");

        let quoted = LauncherLogic.parseCommand("printf '%s %s' one \"two words\"");
        compare(quoted.ok, true);
        compare(quoted.args.length, 4);
        compare(quoted.args[1], "%s %s");
        compare(quoted.args[3], "two words");

        let escaped = LauncherLogic.parseCommand("touch path\\ with\\ spaces");
        compare(escaped.ok, true);
        compare(escaped.args[1], "path with spaces");
    }

    function test_command_parser_rejects_invalid_or_empty_input() {
        let empty = LauncherLogic.parseCommand("   ");
        compare(empty.ok, false);
        verify(empty.error.length > 0);

        let quote = LauncherLogic.parseCommand("printf 'unterminated");
        compare(quote.ok, false);
        verify(quote.error.length > 0);

        let escape = LauncherLogic.parseCommand("printf trailing\\");
        compare(escape.ok, false);
        verify(escape.error.length > 0);
    }

    function test_fuzzy_ranking_matches_and_orders_items() {
        let items = [
            { title: "Firefox", subtitle: "Web Browser" },
            { title: "Files", subtitle: "File Manager" },
            { title: "Terminal", subtitle: "Console" }
        ];
        let ranked = LauncherLogic.rankItems("fx", items);
        compare(ranked.length, 1);
        compare(ranked[0].title, "Firefox");

        let all = LauncherLogic.rankItems("", items);
        compare(all.length, 3);

        let none = LauncherLogic.rankItems("zzz", items);
        compare(none.length, 0);
    }

    function test_overlay_session_generation_advances_only_for_meaningful_transitions() {
        let closed = OverlayState.makeState("", null, 7);
        let opened = OverlayState.reduce(closed,
            { type: "open", kind: "launcher", origin: { source: "widget", screen: screenA, explicit: true } },
            [screenA, screenB], {});
        compare(opened.state.generation, 8);

        let sameOpen = OverlayState.reduce(opened.state,
            { type: "open", kind: "launcher", origin: { source: "ipc", screen: screenB, explicit: true } },
            [screenA, screenB], {});
        compare(sameOpen.state.generation, 8);

        let wrongClose = OverlayState.reduce(sameOpen.state,
            { type: "close", kind: "power" }, [screenA, screenB], {});
        compare(wrongClose.state.generation, 8);

        let switched = OverlayState.reduce(wrongClose.state,
            { type: "open", kind: "power", origin: { source: "widget", screen: screenB, explicit: true } },
            [screenA, screenB], {});
        compare(switched.state.generation, 9);

        let modeChanged = OverlayState.bumpGeneration(switched.state);
        compare(modeChanged.generation, 10);
        compare(modeChanged.activeKind, "power");
        compare(modeChanged.targetScreen, screenB);
    }

    function test_overlay_session_match_rejects_old_kind_screen_or_generation() {
        let state = OverlayState.makeState("launcher", screenA, 12);
        compare(OverlayState.matchesSession(state, "launcher", screenA, 12), true);
        compare(OverlayState.matchesSession(state, "power", screenA, 12), false);
        compare(OverlayState.matchesSession(state, "launcher", screenB, 12), false);
        compare(OverlayState.matchesSession(state, "launcher", screenA, 11), false);
    }

    function test_operation_state_rejects_reentrant_begin_and_stale_finish() {
        let first = OperationState.begin(OperationState.idle());
        compare(first.accepted, true);
        compare(OperationState.isBusy(first.state), true);

        let repeated = OperationState.begin(first.state);
        compare(repeated.accepted, false);
        compare(repeated.token, first.token);

        let stale = OperationState.finish(first.state, first.token + 1);
        compare(stale.accepted, false);
        compare(OperationState.isBusy(stale.state), true);

        let completed = OperationState.finish(stale.state, first.token);
        compare(completed.accepted, true);
        compare(OperationState.isBusy(completed.state), false);
    }

    function test_operation_state_failed_start_timeout_resets_busy_state() {
        let launch = OperationState.begin(OperationState.idle());
        let timeout = OperationState.startupTimeout(launch.state, launch.token);
        compare(timeout.accepted, true);
        compare(OperationState.isBusy(timeout.state), false);

        let next = OperationState.begin(timeout.state);
        compare(next.accepted, true);
        verify(next.token > launch.token);
    }

    function test_operation_state_liveness_prevents_false_startup_timeout() {
        let launch = OperationState.begin(OperationState.idle());
        let live = OperationState.started(launch.state, launch.token);
        compare(live.accepted, true);

        let timeout = OperationState.startupTimeout(live.state, launch.token);
        compare(timeout.accepted, false);
        compare(OperationState.isBusy(timeout.state), true);
    }

    function mediaPlayer(id, playing, title, artist) {
        return {
            uniqueId: id,
            dbusName: "org.mpris.MediaPlayer2." + id,
            identity: id.toUpperCase(),
            isPlaying: playing,
            trackTitle: title ?? "",
            trackArtist: artist ?? "",
            trackAlbum: "",
            trackAlbumArtist: ""
        };
    }

    function test_media_selection_handles_zero_one_and_multiple_players() {
        compare(MediaLogic.choosePlayer([], ""), null);

        let only = mediaPlayer("solo", false, "", "");
        compare(MediaLogic.choosePlayer([only], ""), only);

        let fallback = mediaPlayer("alpha", false, "", "");
        let metadata = mediaPlayer("beta", false, "Song", "Artist");
        compare(MediaLogic.choosePlayer([fallback, metadata], ""), metadata);
    }

    function test_media_selection_prefers_playing_over_paused_metadata() {
        let paused = mediaPlayer("alpha", false, "Paused song", "Artist");
        let playing = mediaPlayer("zeta", true, "", "");
        compare(MediaLogic.choosePlayer([paused, playing], ""), playing);
    }

    function test_media_explicit_selection_persists_then_falls_back_after_removal() {
        let playing = mediaPlayer("alpha", true, "Song", "Artist");
        let explicit = mediaPlayer("zeta", false, "", "");
        compare(MediaLogic.choosePlayer([playing, explicit], "zeta"), explicit);
        compare(MediaLogic.choosePlayer([playing], "zeta"), playing);
    }

    function test_media_player_cycle_is_stable_and_wraps() {
        let alpha = mediaPlayer("alpha", false, "", "");
        let beta = mediaPlayer("beta", false, "", "");
        let zeta = mediaPlayer("zeta", false, "", "");
        let unordered = [zeta, alpha, beta];

        compare(MediaLogic.cyclePlayerId(unordered, "alpha", 1), "beta");
        compare(MediaLogic.cyclePlayerId(unordered, "zeta", 1), "alpha");
        compare(MediaLogic.cyclePlayerId(unordered, "alpha", -1), "zeta");
        compare(MediaLogic.cyclePlayerId([], "alpha", 1), "");
    }

    function test_media_selection_ties_use_stable_id_order() {
        let zeta = mediaPlayer("zeta", false, "Song", "Artist");
        let alpha = mediaPlayer("alpha", false, "Song", "Artist");
        compare(MediaLogic.choosePlayer([zeta, alpha], ""), alpha);
    }

    function seekableMediaPlayer(length) {
        return {
            canControl: true,
            canSeek: true,
            positionSupported: true,
            lengthSupported: true,
            length: length
        };
    }

    function test_media_timeline_rejects_nan() {
        compare(MediaLogic.finiteTimelineValue(NaN), 0);
    }

    function test_media_timeline_rejects_positive_infinity() {
        compare(MediaLogic.finiteTimelineValue(Infinity), 0);
    }

    function test_media_timeline_rejects_negative_infinity() {
        compare(MediaLogic.finiteTimelineValue(-Infinity), 0);
    }

    function test_media_timeline_rejects_negative_values() {
        compare(MediaLogic.finiteTimelineValue(-1), 0);
    }

    function test_media_timeline_preserves_finite_nonnegative_values() {
        compare(MediaLogic.finiteTimelineValue(0), 0);
        compare(MediaLogic.finiteTimelineValue(42.5), 42.5);
    }

    function test_media_can_seek_rejects_nonfinite_length() {
        compare(MediaLogic.canSeek(seekableMediaPlayer(NaN)), false);
        compare(MediaLogic.canSeek(seekableMediaPlayer(Infinity)), false);
        compare(MediaLogic.canSeek(seekableMediaPlayer(-Infinity)), false);
    }

    function test_media_can_seek_requires_positive_length_and_capabilities() {
        compare(MediaLogic.canSeek(seekableMediaPlayer(0)), false);
        compare(MediaLogic.canSeek(seekableMediaPlayer(-1)), false);

        let unsupported = seekableMediaPlayer(120);
        unsupported.positionSupported = false;
        compare(MediaLogic.canSeek(unsupported), false);

        let uncontrollable = seekableMediaPlayer(120);
        uncontrollable.canControl = false;
        compare(MediaLogic.canSeek(uncontrollable), false);
        compare(MediaLogic.canSeek(seekableMediaPlayer(120)), true);
    }

    function test_media_seek_rejects_nan_and_infinity() {
        compare(MediaLogic.clampedSeekPosition(NaN, 120), null);
        compare(MediaLogic.clampedSeekPosition(Infinity, 120), null);
        compare(MediaLogic.clampedSeekPosition(-Infinity, 120), null);
    }

    function test_media_seek_rejects_nonfinite_or_nonpositive_length() {
        compare(MediaLogic.clampedSeekPosition(30, NaN), null);
        compare(MediaLogic.clampedSeekPosition(30, Infinity), null);
        compare(MediaLogic.clampedSeekPosition(30, -Infinity), null);
        compare(MediaLogic.clampedSeekPosition(30, 0), null);
        compare(MediaLogic.clampedSeekPosition(30, -1), null);
    }

    function test_media_seek_clamps_negative_input() {
        compare(MediaLogic.clampedSeekPosition(-1, 120), 0);
    }

    function test_media_seek_clamps_over_length_input() {
        compare(MediaLogic.clampedSeekPosition(121, 120), 120);
    }

    function test_media_seek_preserves_valid_finite_input() {
        compare(MediaLogic.clampedSeekPosition(42.5, 120), 42.5);
    }
}
