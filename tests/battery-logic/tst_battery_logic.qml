import QtQuick
import QtTest
import "../../Services/BatteryLogic.js" as BatteryLogic

TestCase {
    name: "BatteryLogic"

    function battery(overrides) {
        let result = {
            ready: true,
            isLaptopBattery: true,
            isPresent: true,
            percentage: 0.5,
            state: 2,
            timeToEmpty: 3600,
            timeToFull: 0
        };
        const values = overrides ?? {};
        for (const key in values) result[key] = values[key];
        return result;
    }

    function aggregate(overrides) {
        let result = {
            ready: true,
            percentage: 0.75,
            state: 1,
            timeToEmpty: 0,
            timeToFull: 1800
        };
        const values = overrides ?? {};
        for (const key in values) result[key] = values[key];
        return result;
    }

    function test_no_device_has_no_source() {
        compare(BatteryLogic.qualifyingBatteries([]).length, 0);
        compare(BatteryLogic.chooseSource([], aggregate({})), null);

        const unavailable = BatteryLogic.project(null, null, false);
        compare(unavailable.available, false);
        compare(unavailable.batteryCount, 0);
        compare(unavailable.ratio, null);
        compare(unavailable.onBattery, false);
        compare(unavailable.onAc, false);
    }

    function test_real_battery_predicate_requires_all_flags() {
        verify(BatteryLogic.isQualifyingBattery(battery({})));
        compare(BatteryLogic.isQualifyingBattery(battery({ ready: false })), false);
        compare(BatteryLogic.isQualifyingBattery(battery({ isLaptopBattery: false })), false);
        compare(BatteryLogic.isQualifyingBattery(battery({ isPresent: false })), false);
        compare(BatteryLogic.isQualifyingBattery(null), false);
    }

    function test_ups_peripheral_absent_and_unready_are_rejected() {
        const ups = battery({ isLaptopBattery: false, type: 3, powerSupply: true });
        const mouse = battery({ isLaptopBattery: false, type: 5, powerSupply: false });
        const absent = battery({ isPresent: false });
        const unready = battery({ ready: false });
        compare(BatteryLogic.qualifyingBatteries([ups, mouse, absent, unready]).length, 0);
    }

    function test_one_battery_prefers_ready_aggregate_then_falls_back() {
        const physical = battery({ percentage: 0.4 });
        const display = aggregate({ percentage: 0.8 });
        compare(BatteryLogic.chooseSource([physical], display), display);
        compare(BatteryLogic.chooseSource([physical], aggregate({ ready: false })), physical);
        compare(BatteryLogic.chooseSource([physical], null), physical);
    }

    function test_multiple_batteries_require_ready_aggregate() {
        const first = battery({ percentage: 0.2 });
        const second = battery({ percentage: 0.9 });
        const display = aggregate({ percentage: 0.6 });
        compare(BatteryLogic.chooseSource([first, second], display), display);
        compare(BatteryLogic.chooseSource([first, second], aggregate({ ready: false })), null);
        compare(BatteryLogic.chooseSource([first, second], null), null);
    }

    function test_percentage_validation_rejects_nonfinite_and_out_of_range() {
        compare(BatteryLogic.validRatio(NaN), null);
        compare(BatteryLogic.validRatio(Infinity), null);
        compare(BatteryLogic.validRatio(-Infinity), null);
        compare(BatteryLogic.validRatio(-0.01), null);
        compare(BatteryLogic.validRatio(1.01), null);
        compare(BatteryLogic.validRatio("0.5"), null);
    }

    function test_percentage_boundaries_and_rounding() {
        compare(BatteryLogic.validRatio(0), 0);
        compare(BatteryLogic.validRatio(1), 1);
        compare(BatteryLogic.roundedPercent(0), 0);
        compare(BatteryLogic.roundedPercent(0.104), 10);
        compare(BatteryLogic.roundedPercent(0.105), 11);
        compare(BatteryLogic.roundedPercent(1), 100);
        compare(BatteryLogic.roundedPercent(NaN), null);
    }

    function test_band_thresholds_and_state_priority() {
        compare(BatteryLogic.bandFor(50, 1), "cyan");
        compare(BatteryLogic.bandFor(5, 4), "success");
        compare(BatteryLogic.bandFor(10, 2), "urgent");
        compare(BatteryLogic.bandFor(11, 2), "warning");
        compare(BatteryLogic.bandFor(25, 2), "warning");
        compare(BatteryLogic.bandFor(26, 2), "accent");
        compare(BatteryLogic.bandFor(null, 0), "textDim");
    }

    function test_all_upower_states_have_status_and_flags() {
        const expected = [
            [0, "Unknown", false, false, false, false],
            [1, "Charging", true, false, false, false],
            [2, "Discharging", false, true, false, false],
            [3, "Empty", false, false, false, true],
            [4, "Fully charged", false, false, true, false],
            [5, "Pending charge", false, false, false, false],
            [6, "Pending discharge", false, false, false, false]
        ];
        for (let i = 0; i < expected.length; i++) {
            const row = expected[i];
            compare(BatteryLogic.statusForState(row[0]), row[1]);
            const flags = BatteryLogic.stateFlags(row[0]);
            compare(flags.charging, row[2]);
            compare(flags.discharging, row[3]);
            compare(flags.full, row[4]);
            compare(flags.empty, row[5]);
        }
        compare(BatteryLogic.statusForState(99), "Unknown");
    }

    function test_estimate_is_state_appropriate_finite_and_positive() {
        compare(BatteryLogic.remainingSeconds(battery({ state: 2, timeToEmpty: 90 })), 90);
        compare(BatteryLogic.remainingSeconds(battery({ state: 1, timeToFull: 120 })), 120);
        compare(BatteryLogic.remainingSeconds(battery({ state: 2, timeToEmpty: 0 })), null);
        compare(BatteryLogic.remainingSeconds(battery({ state: 1, timeToFull: -1 })), null);
        compare(BatteryLogic.remainingSeconds(battery({ state: 2, timeToEmpty: NaN })), null);
        compare(BatteryLogic.remainingSeconds(battery({ state: 1, timeToFull: Infinity })), null);
        compare(BatteryLogic.remainingSeconds(battery({ state: 4, timeToEmpty: 90, timeToFull: 120 })), null);
        compare(BatteryLogic.remainingSeconds(battery({ state: 5, timeToFull: 120 })), null);
        compare(BatteryLogic.remainingSeconds(battery({ state: 6, timeToEmpty: 90 })), null);
    }

    function test_icons_follow_state_and_percentage() {
        compare(BatteryLogic.iconFor(50, 1), "󰂄");
        compare(BatteryLogic.iconFor(50, 4), "󰁹");
        compare(BatteryLogic.iconFor(0, 3), "󰂎");
        compare(BatteryLogic.iconFor(null, 0), "󰂑");
        verify(BatteryLogic.iconFor(10, 2) !== BatteryLogic.iconFor(90, 2));
    }

    function test_duration_formatting_boundaries() {
        compare(BatteryLogic.formatDuration(null), "");
        compare(BatteryLogic.formatDuration(0), "");
        compare(BatteryLogic.formatDuration(NaN), "");
        compare(BatteryLogic.formatDuration(Infinity), "");
        compare(BatteryLogic.formatDuration(59), "< 1 min");
        compare(BatteryLogic.formatDuration(60), "1 min");
        compare(BatteryLogic.formatDuration(3599), "59 min");
        compare(BatteryLogic.formatDuration(3600), "1 h");
        compare(BatteryLogic.formatDuration(3660), "1 h 1 min");
        compare(BatteryLogic.formatDuration(7320), "2 h 2 min");
    }

    function test_projection_collapses_multiple_until_aggregate_ready() {
        const devices = [battery({ percentage: 0.2 }), battery({ percentage: 0.8 })];
        const collapsed = BatteryLogic.project(devices, aggregate({ ready: false }), true);
        compare(collapsed.available, false);
        compare(collapsed.batteryCount, 2);
        compare(collapsed.ratio, null);
        compare(collapsed.roundedPercent, null);
        compare(collapsed.onBattery, false);
        compare(collapsed.onAc, false);

        const ready = BatteryLogic.project(devices, aggregate({ percentage: 0.55 }), false);
        compare(ready.available, true);
        compare(ready.batteryCount, 2);
        compare(ready.ratio, 0.55);
        compare(ready.roundedPercent, 55);
        compare(ready.onBattery, false);
        compare(ready.onAc, true);
    }

    function test_projection_preserves_invalid_percentage_as_unknown() {
        const result = BatteryLogic.project([battery({ percentage: NaN })], null, true);
        compare(result.available, true);
        compare(result.hasPercentage, false);
        compare(result.ratio, null);
        compare(result.roundedPercent, null);
    }
}
