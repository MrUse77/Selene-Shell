// Pure deterministic player selection helpers. This file intentionally has no DBus imports.

function _text(value) {
    return value === undefined || value === null ? "" : String(value).trim();
}

function _players(values) {
    const result = [];
    if (!values) return result;
    for (let i = 0; i < values.length; i++) {
        if (values[i]) result.push(values[i]);
    }
    return result;
}

function stableId(player) {
    if (!player) return "";
    return _text(player.uniqueId)
        || _text(player.dbusName)
        || _text(player.desktopEntry)
        || _text(player.identity);
}

function hasMetadata(player) {
    if (!player) return false;
    return _text(player.trackTitle) !== ""
        || _text(player.trackArtist) !== ""
        || _text(player.trackAlbum) !== ""
        || _text(player.trackAlbumArtist) !== "";
}

function finiteTimelineValue(value) {
    return Number.isFinite(value) && value >= 0 ? value : 0;
}

function canSeek(player) {
    return player !== null
        && player !== undefined
        && player.canControl === true
        && player.canSeek === true
        && player.positionSupported === true
        && player.lengthSupported === true
        && Number.isFinite(player.length)
        && player.length > 0;
}

function clampedSeekPosition(seconds, length) {
    if (!Number.isFinite(seconds)
            || !Number.isFinite(length)
            || length <= 0) {
        return null;
    }
    return Math.max(0, Math.min(length, seconds));
}

function sortedPlayers(values) {
    const players = _players(values);
    players.sort((left, right) => {
        const leftId = stableId(left);
        const rightId = stableId(right);
        if (leftId < rightId) return -1;
        if (leftId > rightId) return 1;
        return 0;
    });
    return players;
}

function _priority(player) {
    if (player?.isPlaying === true) return 2;
    if (hasMetadata(player)) return 1;
    return 0;
}

function choosePlayer(values, explicitId) {
    const players = sortedPlayers(values);
    if (players.length === 0) return null;

    const wantedId = _text(explicitId);
    if (wantedId !== "") {
        for (let i = 0; i < players.length; i++) {
            if (stableId(players[i]) === wantedId) return players[i];
        }
    }

    let selected = players[0];
    for (let i = 1; i < players.length; i++) {
        if (_priority(players[i]) > _priority(selected)) selected = players[i];
    }
    return selected;
}

function cyclePlayerId(values, currentId, direction) {
    const players = sortedPlayers(values);
    if (players.length === 0) return "";

    const wantedId = _text(currentId);
    let index = -1;
    for (let i = 0; i < players.length; i++) {
        if (stableId(players[i]) === wantedId) {
            index = i;
            break;
        }
    }

    const step = direction < 0 ? -1 : 1;
    if (index < 0) return stableId(players[step < 0 ? players.length - 1 : 0]);
    return stableId(players[(index + step + players.length) % players.length]);
}
