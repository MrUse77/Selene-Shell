pragma Singleton

import QtQuick
import Quickshell.Services.Mpris
import "MediaLogic.js" as MediaLogic

// Shared MPRIS facade. Selection and position polling live here so every screen
// and bar widget observes the same player without creating duplicate tickers.
Item {
    id: root

    property string _explicitPlayerId: ""

    readonly property var players: MediaLogic.sortedPlayers(Mpris.players.values)
    readonly property int playerCount: players.length
    readonly property bool hasPlayers: playerCount > 0
    readonly property var player: MediaLogic.choosePlayer(players, _explicitPlayerId)
    readonly property string playerId: MediaLogic.stableId(player)
    readonly property int playerIndex: indexOfPlayer(playerId)
    readonly property bool hasMetadata: MediaLogic.hasMetadata(player)
    readonly property string identity: player?.identity
        || player?.desktopEntry
        || player?.dbusName
        || "Media player"

    readonly property bool canTogglePlaying: player !== null
        && player.canControl === true
        && player.canTogglePlaying === true
    readonly property bool canGoPrevious: player !== null
        && player.canControl === true
        && player.canGoPrevious === true
    readonly property bool canGoNext: player !== null
        && player.canControl === true
        && player.canGoNext === true
    readonly property bool canSeek: MediaLogic.canSeek(player)
    readonly property real position: player !== null && player.positionSupported === true
        ? MediaLogic.finiteTimelineValue(player.position)
        : 0
    readonly property real length: player !== null && player.lengthSupported === true
        ? MediaLogic.finiteTimelineValue(player.length)
        : 0

    onPlayersChanged: {
        if (_explicitPlayerId !== "" && !containsPlayerId(_explicitPlayerId)) {
            _explicitPlayerId = "";
        }
    }

    // MPRIS position is queried on demand rather than continuously reactive.
    Timer {
        interval: 1000
        running: root.player !== null
            && root.player.positionSupported === true
            && root.player.isPlaying === true
        repeat: true
        onTriggered: {
            const current = root.player;
            if (current !== null
                    && current.positionSupported === true
                    && current.isPlaying === true) {
                current.positionChanged();
            }
        }
    }

    function containsPlayerId(id) {
        return indexOfPlayer(id) >= 0;
    }

    function indexOfPlayer(id) {
        for (let i = 0; i < players.length; i++) {
            if (MediaLogic.stableId(players[i]) === id) return i;
        }
        return -1;
    }

    function togglePlaying() {
        const current = player;
        if (current !== null
                && current.canControl === true
                && current.canTogglePlaying === true) {
            current.togglePlaying();
        }
    }

    function previous() {
        const current = player;
        if (current !== null
                && current.canControl === true
                && current.canGoPrevious === true) {
            current.previous();
        }
    }

    function next() {
        const current = player;
        if (current !== null
                && current.canControl === true
                && current.canGoNext === true) {
            current.next();
        }
    }

    function selectPreviousPlayer() {
        selectPlayer(-1);
    }

    function selectNextPlayer() {
        selectPlayer(1);
    }

    function selectPlayer(direction) {
        const nextId = MediaLogic.cyclePlayerId(players, playerId, direction);
        if (nextId !== "") _explicitPlayerId = nextId;
    }

    function seekTo(seconds) {
        const current = player;
        if (!MediaLogic.canSeek(current)) return;

        const target = MediaLogic.clampedSeekPosition(seconds, current.length);
        if (target === null) return;
        current.position = target;
    }
}
