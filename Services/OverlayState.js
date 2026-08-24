.pragma library

// Reducer puro de estado para overlays interactivos de Selene.
// No depende de Quickshell ni de Hyprland; puede probarse con qmltestrunner.

const VALID_KINDS = ["launcher", "dashboard", "power"];

function makeState(activeKind, targetScreen, generation) {
    return {
        activeKind: activeKind || "",
        targetScreen: targetScreen || null,
        generation: generation || 0
    };
}

function bumpGeneration(state) {
    state = state || makeState();
    return makeState(state.activeKind, state.targetScreen, (state.generation || 0) + 1);
}

function matchesSession(state, kind, screen, generation) {
    state = state || makeState();
    return state.activeKind === kind
        && state.targetScreen === screen
        && (state.generation || 0) === generation;
}

function transitionState(state, activeKind, targetScreen) {
    const nextKind = activeKind || "";
    const nextScreen = targetScreen || null;
    if (state.activeKind === nextKind && state.targetScreen === nextScreen) {
        return makeState(nextKind, nextScreen, state.generation);
    }
    return makeState(nextKind, nextScreen, state.generation + 1);
}

function isValidKind(kind) {
    return VALID_KINDS.includes(kind);
}

function isScreenValid(screen, liveScreens) {
    if (!liveScreens || liveScreens.length === 0) return false;
    if (!screen) return false;
    for (let i = 0; i < liveScreens.length; i++) {
        if (liveScreens[i] === screen) return true;
    }
    return false;
}

function normalizeState(state, liveScreens) {
    state = makeState(state.activeKind, state.targetScreen, state.generation);
    if (state.activeKind !== "" && !isScreenValid(state.targetScreen, liveScreens)) {
        return transitionState(state, "", null);
    }
    return state;
}

function canOpenOnScreen(origin, fullscreenByScreen) {
    if (!origin || origin.explicit !== false) return true;
    const name = origin.screen?.name ?? "";
    if (name !== "" && fullscreenByScreen && fullscreenByScreen[name]) return false;
    return true;
}

function resolveFocusedScreen(focusedName, liveScreens) {
    if (!liveScreens || liveScreens.length === 0) return null;
    if (focusedName) {
        for (let i = 0; i < liveScreens.length; i++) {
            if (liveScreens[i].name === focusedName) return liveScreens[i];
        }
    }
    for (let i = 0; i < liveScreens.length; i++) {
        if (liveScreens[i].primary) return liveScreens[i];
    }
    return liveScreens[0];
}

function reduce(state, action, liveScreens, fullscreenByScreen) {
    state = normalizeState(state || makeState(), liveScreens || []);
    liveScreens = liveScreens || [];
    fullscreenByScreen = fullscreenByScreen || {};

    const kind = action.kind || "";

    switch (action.type) {
    case "open":
        if (!isValidKind(kind)) return { state: state, accepted: false };
        if (!isScreenValid(action.origin?.screen, liveScreens)) return { state: state, accepted: false };
        if (!canOpenOnScreen(action.origin, fullscreenByScreen)) return { state: state, accepted: false };
        if (state.activeKind === kind) return { state: state, accepted: true };
        return { state: transitionState(state, kind, action.origin.screen), accepted: true };

    case "toggle":
        if (!isValidKind(kind)) return { state: state, accepted: false };
        if (state.activeKind === kind) return { state: transitionState(state, "", null), accepted: true };
        if (!isScreenValid(action.origin?.screen, liveScreens)) return { state: state, accepted: false };
        if (!canOpenOnScreen(action.origin, fullscreenByScreen)) return { state: state, accepted: false };
        return { state: transitionState(state, kind, action.origin.screen), accepted: true };

    case "close":
        if (kind !== "" && state.activeKind !== kind) return { state: state, accepted: true };
        return { state: transitionState(state, "", null), accepted: true };

    case "closeForScreen":
        if (state.targetScreen === action.screen) {
            return { state: transitionState(state, "", null), accepted: true };
        }
        return { state: state, accepted: true };

    default:
        return { state: state, accepted: false };
    }
}
