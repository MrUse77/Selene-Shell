// Pure deterministic battery projection helpers. This file intentionally has no UPower imports.

function _finiteNumber(value) {
    return typeof value === "number" && Number.isFinite(value);
}

function _values(values) {
    const result = [];
    if (!values) return result;
    for (let i = 0; i < values.length; i++) {
        if (values[i]) result.push(values[i]);
    }
    return result;
}

function isQualifyingBattery(device) {
    return device !== null
        && device !== undefined
        && device.ready === true
        && device.isLaptopBattery === true
        && device.isPresent === true;
}

function qualifyingBatteries(values) {
    const devices = _values(values);
    const batteries = [];
    for (let i = 0; i < devices.length; i++) {
        if (isQualifyingBattery(devices[i])) batteries.push(devices[i]);
    }
    return batteries;
}

function chooseSource(batteries, displayDevice) {
    const physical = _values(batteries);
    if (physical.length === 0) return null;

    const aggregateReady = displayDevice !== null
        && displayDevice !== undefined
        && displayDevice.ready === true;
    if (physical.length === 1) return aggregateReady ? displayDevice : physical[0];
    return aggregateReady ? displayDevice : null;
}

function validRatio(value) {
    return _finiteNumber(value) && value >= 0 && value <= 1 ? value : null;
}

function roundedPercent(ratio) {
    const valid = validRatio(ratio);
    return valid === null ? null : Math.round(valid * 100);
}

function stateFlags(state) {
    return {
        charging: state === 1,
        discharging: state === 2,
        empty: state === 3,
        full: state === 4
    };
}

function statusForState(state) {
    switch (state) {
    case 1: return "Charging";
    case 2: return "Discharging";
    case 3: return "Empty";
    case 4: return "Fully charged";
    case 5: return "Pending charge";
    case 6: return "Pending discharge";
    default: return "Unknown";
    }
}

function remainingSeconds(source) {
    if (!source) return null;
    let value = null;
    if (source.state === 2) value = source.timeToEmpty;
    else if (source.state === 1) value = source.timeToFull;
    return _finiteNumber(value) && value > 0 ? value : null;
}

function formatDuration(seconds) {
    if (!_finiteNumber(seconds) || seconds <= 0) return "";
    const totalMinutes = Math.floor(seconds / 60);
    if (totalMinutes < 1) return "< 1 min";
    const hours = Math.floor(totalMinutes / 60);
    const minutes = totalMinutes % 60;
    if (hours === 0) return totalMinutes + " min";
    return hours + " h" + (minutes > 0 ? " " + minutes + " min" : "");
}

function bandFor(percent, state) {
    if (state === 1) return "cyan";
    if (state === 4) return "success";
    if (!_finiteNumber(percent)) return "textDim";
    if (percent <= 10) return "urgent";
    if (percent <= 25) return "warning";
    return "accent";
}

function iconFor(percent, state) {
    if (state === 1) return "󰂄";
    if (state === 4) return "󰁹";
    if (state === 3) return "󰂎";
    if (!_finiteNumber(percent)) return "󰂑";
    if (percent <= 10) return "󰁺";
    if (percent <= 25) return "󰁻";
    if (percent <= 40) return "󰁼";
    if (percent <= 60) return "󰁽";
    if (percent <= 80) return "󰁿";
    return "󰂂";
}

function project(devices, displayDevice, upowerOnBattery) {
    const batteries = qualifyingBatteries(devices);
    const source = chooseSource(batteries, displayDevice);
    const available = source !== null;
    const ratio = available ? validRatio(source.percentage) : null;
    const percent = roundedPercent(ratio);
    const flags = available ? stateFlags(source.state) : stateFlags(0);
    const remaining = available ? remainingSeconds(source) : null;
    const onBattery = available && upowerOnBattery === true;

    return {
        available: available,
        batteryCount: batteries.length,
        ratio: ratio,
        roundedPercent: percent,
        hasPercentage: ratio !== null,
        charging: flags.charging,
        discharging: flags.discharging,
        full: flags.full,
        empty: flags.empty,
        onBattery: onBattery,
        onAc: available && !onBattery,
        remainingSeconds: remaining,
        remainingText: formatDuration(remaining),
        status: available ? statusForState(source.state) : "",
        icon: available ? iconFor(percent, source.state) : "",
        iconName: available && source.iconName ? String(source.iconName) : "",
        band: available ? bandFor(percent, source.state) : "textDim"
    };
}
