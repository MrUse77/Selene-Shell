import QtQuick
import QtTest
import "../../Services/NotificationState.js" as NotificationState

TestCase {
    name: "NotificationState"

    function notification(id, overrides) {
        const value = {
            id: id,
            appName: "Example App",
            appIcon: "example",
            summary: "Summary " + id,
            body: "Body " + id,
            urgency: 1,
            expireTimeout: 5000,
            desktopEntry: "example.desktop",
            image: "image://example/" + id,
            transient: false,
            actions: []
        };
        const changes = overrides ?? {};
        for (const key in changes) value[key] = changes[key];
        return value;
    }

    function ids(records) {
        return records.map(record => record.id).join(",");
    }

    function record(id, urgency) {
        return NotificationState.createRecord(notification(id, { urgency: urgency ?? 1 }), 0);
    }

    function test_normalize_missing_corrupt_and_unknown_state_to_empty_schema_v1() {
        const invalidValues = [
            undefined,
            null,
            "not-json-state",
            [],
            {},
            { schemaVersion: 2, dnd: true, records: [] },
            { schemaVersion: 1, dnd: true, records: "not-an-array" }
        ];

        for (let i = 0; i < invalidValues.length; i++) {
            const state = NotificationState.normalizeState(invalidValues[i]);
            compare(state.schemaVersion, 1);
            compare(state.dnd, false);
            compare(state.records.length, 0);
        }
    }

    function test_create_record_is_stable_value_only_and_serializable() {
        const liveAction = {
            identifier: "open",
            text: "Open",
            invoke: function() { fail("callable action must never be retained"); }
        };
        const liveNotification = notification(42, {
            actions: [liveAction, { identifier: "dismiss", text: "Dismiss" }],
            closeLive: function() { fail("live notification must never be retained"); },
            unknownObject: { value: "ignored" }
        });

        const first = NotificationState.createRecord(liveNotification, 1700000000000);
        const second = NotificationState.createRecord(liveNotification, 1700000000000);
        const serialized = JSON.stringify(first);

        compare(serialized, JSON.stringify(second));
        compare(first.id, "42");
        compare(first.timestamp, 1700000000000);
        compare(first.expireTimeout, 5000);
        compare(first.read, false);
        compare(first.actions.length, 2);
        compare(first.actions[0].identifier, "open");
        compare(first.actions[0].text, "Open");
        compare(Object.keys(first.actions[0]).join(","), "identifier,text");
        verify(serialized.indexOf("invoke") === -1);
        verify(serialized.indexOf("closeLive") === -1);
        verify(serialized.indexOf("dismiss") !== -1);
        verify(serialized.indexOf("unknownObject") === -1);
        verify(JSON.parse(serialized) !== null);
    }

    function test_transient_notifications_are_not_persisted() {
        const state = NotificationState.emptyState();
        const next = NotificationState.insertNotification(
            state,
            notification("transient", { transient: true }),
            1000
        );

        compare(next.records.length, 0);
        compare(state.records.length, 0);
    }

    function test_newest_first_insertion_is_bounded_by_custom_and_default_caps() {
        let state = NotificationState.emptyState();
        for (let i = 0; i < 4; i++) {
            state = NotificationState.insertNotification(state, notification(String(i)), i, 3);
        }
        compare(ids(state.records), "3,2,1");

        let defaultBounded = NotificationState.emptyState();
        for (let j = 0; j < 55; j++) {
            defaultBounded = NotificationState.insertNotification(
                defaultBounded,
                notification(String(j)),
                j
            );
        }
        compare(defaultBounded.records.length, 50);
        compare(defaultBounded.records[0].id, "54");
        compare(defaultBounded.records[49].id, "5");
    }

    function test_unread_is_derived_and_mark_all_read_replaces_records() {
        let state = NotificationState.emptyState();
        state = NotificationState.insertNotification(state, notification("first"), 1);
        state = NotificationState.insertNotification(state, notification("second"), 2);
        const originalRecords = state.records;

        compare(NotificationState.unreadCount(state), 2);
        const marked = NotificationState.markAllRead(state);
        compare(NotificationState.unreadCount(marked), 0);
        verify(marked.records !== originalRecords);
        compare(originalRecords[0].read, false);
        compare(marked.records[0].read, true);
        compare(marked.records[1].read, true);
    }

    function test_remove_one_and_clear_all_replace_arrays() {
        let state = NotificationState.emptyState();
        state = NotificationState.insertNotification(state, notification("first"), 1);
        state = NotificationState.insertNotification(state, notification("second"), 2);
        const originalRecords = state.records;

        const removed = NotificationState.removeOne(state, "second");
        compare(ids(removed.records), "first");
        verify(removed.records !== originalRecords);
        compare(originalRecords.length, 2);

        const cleared = NotificationState.clearAll(removed);
        compare(cleared.records.length, 0);
        verify(cleared.records !== removed.records);
    }

    function test_dnd_is_a_persisted_state_transition() {
        const enabled = NotificationState.setDnd(NotificationState.emptyState(), true);
        compare(enabled.schemaVersion, 1);
        compare(enabled.dnd, true);
        compare(enabled.records.length, 0);

        const hydrated = NotificationState.normalizeState(JSON.parse(JSON.stringify(enabled)));
        compare(hydrated.dnd, true);
        compare(hydrated.schemaVersion, 1);
    }

    function test_dnd_suppresses_ordinary_popup_but_critical_bypasses() {
        const ordinary = record("ordinary");
        const critical = record("critical", 2);

        compare(NotificationState.isPopupEligible(ordinary, false), true);
        compare(NotificationState.isPopupEligible(ordinary, true), false);
        compare(NotificationState.isPopupEligible(critical, true), true);
    }

    function test_popup_overflow_never_evicts_critical_for_ordinary() {
        const criticalA = record("critical-a", 2);
        const criticalB = record("critical-b", 2);
        const ordinary = record("ordinary");

        const rejectedOrdinary = NotificationState.selectPopups(
            [criticalB, criticalA], ordinary, 2
        );
        compare(ids(rejectedOrdinary), "critical-b,critical-a");

        const existingOrdinary = record("old-ordinary");
        const admittedOrdinary = NotificationState.selectPopups(
            [criticalA, existingOrdinary], ordinary, 2
        );
        compare(ids(admittedOrdinary), "ordinary,critical-a");

        const criticalWins = NotificationState.selectPopups(
            [criticalA, existingOrdinary], record("new-critical", 2), 2
        );
        compare(ids(criticalWins), "new-critical,critical-a");
    }
}
