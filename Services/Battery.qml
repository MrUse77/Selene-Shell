pragma Singleton

import QtQuick
import Quickshell.Services.UPower
import "BatteryLogic.js" as BatteryLogic

// Shared UPower facade. Physical-device qualification and aggregate selection
// are centralized here so the bar and dashboard remain passive consumers.
Item {
    id: root

    readonly property var _projection: BatteryLogic.project(
        UPower.devices.values,
        UPower.displayDevice,
        UPower.onBattery
    )

    readonly property bool available: _projection.available
    readonly property int batteryCount: _projection.batteryCount
    readonly property var ratio: _projection.ratio
    readonly property var roundedPercent: _projection.roundedPercent
    readonly property bool hasPercentage: _projection.hasPercentage
    readonly property bool charging: _projection.charging
    readonly property bool discharging: _projection.discharging
    readonly property bool full: _projection.full
    readonly property bool empty: _projection.empty
    readonly property bool onBattery: _projection.onBattery
    readonly property bool onAc: _projection.onAc
    readonly property var remainingSeconds: _projection.remainingSeconds
    readonly property string remainingText: _projection.remainingText
    readonly property string status: _projection.status
    readonly property string icon: _projection.icon
    readonly property string iconName: _projection.iconName
    readonly property string band: _projection.band
}
