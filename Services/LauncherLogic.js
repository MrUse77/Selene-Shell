.pragma library

const MODES = ["apps", "windows", "run", "themes"];

function normalizeMode(mode) {
    return MODES.indexOf(mode) >= 0 ? mode : "apps";
}

function cycleMode(mode, delta) {
    const current = MODES.indexOf(normalizeMode(mode));
    const next = (current + delta % MODES.length + MODES.length) % MODES.length;
    return MODES[next];
}

function fuzzyScore(query, text) {
    const q = (query || "").trim().toLowerCase();
    const candidate = (text || "").toLowerCase();
    if (q === "") return 0.01;

    let position = 0;
    let score = 0;
    let streak = 0;
    for (let i = 0; i < q.length; i++) {
        const index = candidate.indexOf(q[i], position);
        if (index < 0) return 0;
        streak = index === position ? streak + 2 : 0;
        score += 1 + streak;
        position = index + 1;
    }
    if (candidate.startsWith(q)) score += 10;
    return score;
}

function rankItems(query, items) {
    const ranked = [];
    const source = items || [];
    for (let i = 0; i < source.length; i++) {
        const item = source[i];
        const titleScore = fuzzyScore(query, item.title || "") * 2;
        const subtitleScore = fuzzyScore(query, item.subtitle || "") * 0.4;
        const score = titleScore + subtitleScore;
        if (score > 0) ranked.push({ item: item, score: score });
    }
    ranked.sort(function(a, b) {
        if (b.score !== a.score) return b.score - a.score;
        return (a.item.title || "").localeCompare(b.item.title || "");
    });
    return ranked.map(function(entry) { return entry.item; });
}

// Split a command line without invoking a shell. Quotes and backslash escaping
// are supported, while expansion, substitution, pipelines and redirection are
// intentionally not interpreted so every returned array element remains one
// process argument.
function parseCommand(input) {
    const text = input || "";
    const args = [];
    let token = "";
    let quote = "";
    let escaped = false;
    let started = false;

    for (let i = 0; i < text.length; i++) {
        const ch = text[i];
        if (escaped) {
            token += ch;
            escaped = false;
            started = true;
            continue;
        }
        if (ch === "\\" && quote !== "'") {
            escaped = true;
            started = true;
            continue;
        }
        if (quote !== "") {
            if (ch === quote) quote = "";
            else token += ch;
            started = true;
            continue;
        }
        if (ch === "'" || ch === '"') {
            quote = ch;
            started = true;
            continue;
        }
        if (/\s/.test(ch)) {
            if (started) {
                args.push(token);
                token = "";
                started = false;
            }
            continue;
        }
        token += ch;
        started = true;
    }

    if (escaped) return { ok: false, args: [], error: "Trailing escape in command" };
    if (quote !== "") return { ok: false, args: [], error: "Unterminated quote in command" };
    if (started) args.push(token);
    if (args.length === 0) return { ok: false, args: [], error: "Enter a command to run" };
    return { ok: true, args: args, error: "" };
}
