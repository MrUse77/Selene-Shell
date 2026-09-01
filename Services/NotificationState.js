.pragma library

// Pure schema-v1 notification state and popup-selection logic.
// Outputs contain JSON-safe values only; live notification objects are never retained.

var SCHEMA_VERSION = 1;
var DEFAULT_RETENTION_CAP = 50;

function _isObject(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value);
}

function _string(value) {
    if (value === null || value === undefined) return "";
    const type = typeof value;
    return type === "string" || type === "number" || type === "boolean"
        ? String(value)
        : "";
}

function _finiteInteger(value, fallback) {
    return typeof value === "number" && Number.isFinite(value)
        ? Math.floor(value)
        : fallback;
}

function _urgency(value) {
    if (value === "critical") return 2;
    if (value === "low") return 0;
    const numeric = _finiteInteger(value, 1);
    return numeric >= 0 && numeric <= 2 ? numeric : 1;
}

function _retentionCap(value) {
    const cap = _finiteInteger(value, DEFAULT_RETENTION_CAP);
    return cap > 0 ? cap : DEFAULT_RETENTION_CAP;
}

function _action(action) {
    if (!_isObject(action)) return null;
    return {
        identifier: _string(action.identifier),
        text: _string(action.text)
    };
}

function _actions(actions) {
    const result = [];
    if (!actions || typeof actions.length !== "number") return result;
    for (let i = 0; i < actions.length; i++) {
        const action = _action(actions[i]);
        if (action !== null) result.push(action);
    }
    return result;
}

function createRecord(notification, timestamp) {
    const source = _isObject(notification) ? notification : {};
    const recordedAt = _finiteInteger(timestamp, _finiteInteger(source.timestamp, 0));

    return {
        id: _string(source.id),
        appName: _string(source.appName),
        appIcon: _string(source.appIcon),
        summary: _string(source.summary),
        body: _string(source.body),
        urgency: _urgency(source.urgency),
        timestamp: Math.max(0, recordedAt),
        expireTimeout: Math.max(0, _finiteInteger(source.expireTimeout, 0)),
        desktopEntry: _string(source.desktopEntry),
        image: _string(source.image),
        read: source.read === true,
        actions: _actions(source.actions)
    };
}

function _persistedRecord(value) {
    if (!_isObject(value)) return null;
    return createRecord(value, value.timestamp);
}

function emptyState() {
    return {
        schemaVersion: SCHEMA_VERSION,
        dnd: false,
        records: []
    };
}

function normalizeState(value, retentionCap) {
    if (!_isObject(value)
            || value.schemaVersion !== SCHEMA_VERSION
            || typeof value.dnd !== "boolean"
            || !Array.isArray(value.records)) {
        return emptyState();
    }

    const cap = _retentionCap(retentionCap);
    const records = [];
    for (let i = 0; i < value.records.length && records.length < cap; i++) {
        const record = _persistedRecord(value.records[i]);
        if (record !== null) records.push(record);
    }

    return {
        schemaVersion: SCHEMA_VERSION,
        dnd: value.dnd,
        records: records
    };
}

function _stateWith(records, dnd) {
    return {
        schemaVersion: SCHEMA_VERSION,
        dnd: dnd,
        records: records
    };
}

function insertNotification(state, notification, timestamp, retentionCap) {
    const normalized = normalizeState(state, retentionCap);
    if (!_isObject(notification) || notification.transient === true) {
        return _stateWith(normalized.records.slice(), normalized.dnd);
    }

    const record = createRecord(notification, timestamp);
    const records = [record];
    for (let i = 0; i < normalized.records.length; i++) {
        if (normalized.records[i].id !== record.id) records.push(normalized.records[i]);
    }
    records.length = Math.min(records.length, _retentionCap(retentionCap));
    return _stateWith(records, normalized.dnd);
}

function unreadCount(state) {
    const records = normalizeState(state).records;
    let count = 0;
    for (let i = 0; i < records.length; i++) {
        if (!records[i].read) count++;
    }
    return count;
}

function markAllRead(state) {
    const normalized = normalizeState(state);
    const records = normalized.records.map(function(record) {
        const copy = createRecord(record, record.timestamp);
        copy.read = true;
        return copy;
    });
    return _stateWith(records, normalized.dnd);
}

function removeOne(state, id) {
    const normalized = normalizeState(state);
    const targetId = _string(id);
    const records = normalized.records.filter(function(record) {
        return record.id !== targetId;
    });
    return _stateWith(records, normalized.dnd);
}

function clearAll(state) {
    const normalized = normalizeState(state);
    return _stateWith([], normalized.dnd);
}

function setDnd(state, enabled) {
    const normalized = normalizeState(state);
    return _stateWith(normalized.records.slice(), enabled === true);
}

function isCritical(record) {
    return _isObject(record) && _urgency(record.urgency) === 2;
}

function isPopupEligible(record, dnd) {
    return _isObject(record) && (dnd !== true || isCritical(record));
}

function selectPopups(currentPopups, incomingPopup, visibleCap) {
    const cap = _finiteInteger(visibleCap, 0);
    if (cap <= 0 || !_isObject(incomingPopup)) return [];

    const incoming = _persistedRecord(incomingPopup);
    if (incoming === null) return [];

    const candidates = [incoming];
    const current = Array.isArray(currentPopups) ? currentPopups : [];
    for (let i = 0; i < current.length; i++) {
        const record = _persistedRecord(current[i]);
        if (record !== null && record.id !== incoming.id) candidates.push(record);
    }

    while (candidates.length > cap) {
        let removable = -1;
        for (let i = candidates.length - 1; i >= 0; i--) {
            if (!isCritical(candidates[i])) {
                removable = i;
                break;
            }
        }
        if (removable === -1) removable = candidates.length - 1;
        candidates.splice(removable, 1);
    }

    return candidates;
}
