.pragma library

// Reducer puro de estado para overlays interactivos de Selene.
// No depende de Quickshell ni de Hyprland; puede probarse con qmltestrunner.

const VALID_KINDS = ["launcher", "dashboard", "power"];

function makeState(activeKind, targetScreen) {
    return {
        activeKind: activeKind || "",
        targetScreen: targetScreen || null
    };
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
    if (state.activeKind !== "" && !isScreenValid(state.targetScreen, liveScreens)) {
        return makeState();
    }
    return makeState(state.activeKind, state.targetScreen);
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
        return { state: makeState(kind, action.origin.screen), accepted: true };

    case "toggle":
        if (!isValidKind(kind)) return { state: state, accepted: false };
        if (state.activeKind === kind) return { state: makeState(), accepted: true };
        if (!isScreenValid(action.origin?.screen, liveScreens)) return { state: state, accepted: false };
        if (!canOpenOnScreen(action.origin, fullscreenByScreen)) return { state: state, accepted: false };
        return { state: makeState(kind, action.origin.screen), accepted: true };

    case "close":
        if (kind !== "" && state.activeKind !== kind) return { state: state, accepted: true };
        return { state: makeState(), accepted: true };

    case "closeForScreen":
        if (state.targetScreen === action.screen) return { state: makeState(), accepted: true };
        return { state: state, accepted: true };

    default:
        return { state: state, accepted: false };
    }
}
