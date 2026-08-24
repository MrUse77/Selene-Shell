.pragma library

function normalize(state) {
    if (!state) return idle();
    return {
        generation: state.generation || 0,
        active: state.active || 0,
        started: state.started === true
    };
}

function idle(generation) {
    return {
        generation: generation || 0,
        active: 0,
        started: false
    };
}

function isBusy(state) {
    return normalize(state).active !== 0;
}

function begin(state) {
    const current = normalize(state);
    if (current.active !== 0) {
        return { accepted: false, token: current.active, state: current };
    }

    const token = current.generation + 1;
    return {
        accepted: true,
        token: token,
        state: { generation: token, active: token, started: false }
    };
}

function started(state, token) {
    const current = normalize(state);
    if (current.active !== token) {
        return { accepted: false, token: token, state: current };
    }
    return {
        accepted: true,
        token: token,
        state: { generation: current.generation, active: token, started: true }
    };
}

function finish(state, token) {
    const current = normalize(state);
    if (current.active !== token) {
        return { accepted: false, token: token, state: current };
    }
    return {
        accepted: true,
        token: token,
        state: idle(current.generation)
    };
}

function startupTimeout(state, token) {
    const current = normalize(state);
    if (current.active !== token || current.started) {
        return { accepted: false, token: token, state: current };
    }
    return finish(current, token);
}
