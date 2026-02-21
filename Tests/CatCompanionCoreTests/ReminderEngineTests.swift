import XCTest
@testable import CatCompanionCore

@MainActor
final class ReminderEngineTests: XCTestCase {
    private func makeStore(
        suiteName: String = "CatCompanion.ReminderEngineTests.\(UUID().uuidString)"
    ) -> (SettingsStore, UserDefaults, String) {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (SettingsStore(userDefaults: defaults), defaults, suiteName)
    }

    private func configureSingleHydratePlan(on store: SettingsStore, interval: Int = 10, snooze: Int = 5) {
        var settings = store.settings
        for type in ReminderType.allCases {
            var plan = settings.plans[type] ?? ReminderPlan(
                enabled: true,
                intervalMinutes: type.defaultIntervalMinutes,
                quietHours: QuietHours(),
                snoozeMinutes: type.defaultSnoozeMinutes
            )
            plan.enabled = (type == .hydrate)
            plan.intervalMinutes = interval
            plan.snoozeMinutes = snooze
            // Disable quiet hours to keep tests deterministic across host time zones.
            plan.quietHours = QuietHours(startHour: 0, endHour: 0)
            settings.plans[type] = plan
        }
        store.settings = settings
    }

    private func configureHydrateAndStandPlans(
        on store: SettingsStore,
        interval: Int = 10,
        hydrateSnooze: Int = 5,
        standSnooze: Int = 10
    ) {
        var settings = store.settings
        for type in ReminderType.allCases {
            var plan = settings.plans[type] ?? ReminderPlan(
                enabled: true,
                intervalMinutes: type.defaultIntervalMinutes,
                quietHours: QuietHours(),
                snoozeMinutes: type.defaultSnoozeMinutes
            )
            switch type {
            case .hydrate:
                plan.enabled = true
                plan.intervalMinutes = interval
                plan.snoozeMinutes = hydrateSnooze
            case .stand:
                plan.enabled = true
                plan.intervalMinutes = interval
                plan.snoozeMinutes = standSnooze
            case .restEyes:
                plan.enabled = false
            }
            plan.quietHours = QuietHours(startHour: 0, endHour: 0)
            settings.plans[type] = plan
        }
        store.settings = settings
    }

    func testEvaluateNowTriggersOverdueReminder() {
        let (store, defaults, suiteName) = makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        configureSingleHydratePlan(on: store)

        let baseNow = Date(timeIntervalSince1970: 1_000_000)
        var settings = store.settings
        settings.states[.hydrate] = ReminderState(
            lastCompletedAt: baseNow.addingTimeInterval(-15 * 60),
            lastTriggeredAt: nil,
            snoozedUntil: nil
        )
        store.settings = settings

        let engine = ReminderEngine(settingsStore: store, nowProvider: { baseNow })
        engine.evaluateNow()

        XCTAssertEqual(engine.activeReminder, .hydrate)
        XCTAssertEqual(store.settings.states[.hydrate]?.lastTriggeredAt, baseNow)
    }

    func testCompleteActiveReminderRecordsCompletionTime() {
        let (store, defaults, suiteName) = makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        configureSingleHydratePlan(on: store)

        let triggeredAt = Date(timeIntervalSince1970: 2_000_000)
        var now = triggeredAt

        var settings = store.settings
        settings.states[.hydrate] = ReminderState(
            lastCompletedAt: triggeredAt.addingTimeInterval(-20 * 60),
            lastTriggeredAt: nil,
            snoozedUntil: nil
        )
        store.settings = settings

        let engine = ReminderEngine(settingsStore: store, nowProvider: { now })
        engine.evaluateNow()
        XCTAssertEqual(engine.activeReminder, .hydrate)

        now = triggeredAt.addingTimeInterval(90)
        engine.completeActiveReminder()

        XCTAssertNil(engine.activeReminder)
        XCTAssertEqual(store.settings.states[.hydrate]?.lastCompletedAt, now)
        XCTAssertNil(store.settings.states[.hydrate]?.snoozedUntil)
    }

    func testAutoDismissSnoozesAfterTimeout() {
        let (store, defaults, suiteName) = makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        configureSingleHydratePlan(on: store, interval: 10, snooze: 5)

        let initialNow = Date(timeIntervalSince1970: 3_000_000)
        var now = initialNow

        var settings = store.settings
        settings.states[.hydrate] = ReminderState(
            lastCompletedAt: initialNow.addingTimeInterval(-20 * 60),
            lastTriggeredAt: nil,
            snoozedUntil: nil
        )
        store.settings = settings

        let engine = ReminderEngine(settingsStore: store, nowProvider: { now })
        engine.evaluateNow()
        XCTAssertEqual(engine.activeReminder, .hydrate)

        now = initialNow.addingTimeInterval(6 * 60)
        engine.evaluateNow()

        XCTAssertNil(engine.activeReminder)
        XCTAssertEqual(store.settings.states[.hydrate]?.snoozedUntil, now.addingTimeInterval(5 * 60))
    }

    func testCompleteReminderByTypeUpdatesStateWithoutActiveReminder() {
        let (store, defaults, suiteName) = makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        configureSingleHydratePlan(on: store)

        let now = Date(timeIntervalSince1970: 4_000_000)
        let engine = ReminderEngine(settingsStore: store, nowProvider: { now })

        engine.completeReminder(.hydrate)

        XCTAssertNil(engine.activeReminder)
        XCTAssertEqual(store.settings.states[.hydrate]?.lastCompletedAt, now)
        XCTAssertNil(store.settings.states[.hydrate]?.snoozedUntil)
    }

    func testSnoozeReminderByTypeUpdatesStateWithoutActiveReminder() {
        let (store, defaults, suiteName) = makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        configureSingleHydratePlan(on: store, interval: 10, snooze: 15)

        let now = Date(timeIntervalSince1970: 5_000_000)
        let engine = ReminderEngine(settingsStore: store, nowProvider: { now })

        engine.snoozeReminder(.hydrate)

        XCTAssertNil(engine.activeReminder)
        XCTAssertEqual(store.settings.states[.hydrate]?.snoozedUntil, now.addingTimeInterval(15 * 60))
    }

    func testSnoozeActiveReminderUsesPlanAndClearsActiveReminder() {
        let (store, defaults, suiteName) = makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        configureSingleHydratePlan(on: store, interval: 10, snooze: 12)

        let baseNow = Date(timeIntervalSince1970: 6_000_000)
        var now = baseNow

        var settings = store.settings
        settings.states[.hydrate] = ReminderState(
            lastCompletedAt: baseNow.addingTimeInterval(-20 * 60),
            lastTriggeredAt: nil,
            snoozedUntil: nil
        )
        store.settings = settings

        let engine = ReminderEngine(settingsStore: store, nowProvider: { now })
        engine.evaluateNow()
        XCTAssertEqual(engine.activeReminder, .hydrate)

        now = baseNow.addingTimeInterval(30)
        engine.snoozeActiveReminder()

        XCTAssertNil(engine.activeReminder)
        XCTAssertEqual(store.settings.states[.hydrate]?.snoozedUntil, now.addingTimeInterval(12 * 60))
    }

    func testActiveReminderBlocksOtherTriggersUntilHandled() {
        let (store, defaults, suiteName) = makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        configureHydrateAndStandPlans(on: store, interval: 10, hydrateSnooze: 5, standSnooze: 10)

        let baseNow = Date(timeIntervalSince1970: 7_000_000)
        var now = baseNow

        var settings = store.settings
        settings.states[.hydrate] = ReminderState(
            lastCompletedAt: baseNow.addingTimeInterval(-20 * 60),
            lastTriggeredAt: nil,
            snoozedUntil: nil
        )
        settings.states[.stand] = ReminderState(
            lastCompletedAt: baseNow.addingTimeInterval(-20 * 60),
            lastTriggeredAt: nil,
            snoozedUntil: nil
        )
        store.settings = settings

        let engine = ReminderEngine(settingsStore: store, nowProvider: { now })
        engine.evaluateNow()
        XCTAssertEqual(engine.activeReminder, .hydrate)
        XCTAssertEqual(store.settings.states[.hydrate]?.lastTriggeredAt, baseNow)
        XCTAssertNil(store.settings.states[.stand]?.lastTriggeredAt)

        now = baseNow.addingTimeInterval(2 * 60)
        engine.evaluateNow()

        XCTAssertEqual(engine.activeReminder, .hydrate)
        XCTAssertNil(store.settings.states[.stand]?.lastTriggeredAt)

        engine.completeActiveReminder()
        engine.evaluateNow()
        XCTAssertNil(engine.activeReminder)
        XCTAssertNil(store.settings.states[.stand]?.lastTriggeredAt)

        now = baseNow.addingTimeInterval(4 * 60)
        engine.evaluateNow()
        XCTAssertEqual(engine.activeReminder, .stand)
    }

    func testCompleteActiveReminderDoesNotImmediatelyRetrigger() {
        let (store, defaults, suiteName) = makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        configureSingleHydratePlan(on: store, interval: 30, snooze: 10)

        let baseNow = Date(timeIntervalSince1970: 8_000_000)
        var now = baseNow

        var settings = store.settings
        settings.states[.hydrate] = ReminderState(
            lastCompletedAt: baseNow.addingTimeInterval(-60 * 60),
            lastTriggeredAt: nil,
            snoozedUntil: nil
        )
        store.settings = settings

        let engine = ReminderEngine(settingsStore: store, nowProvider: { now })
        engine.evaluateNow()
        XCTAssertEqual(engine.activeReminder, .hydrate)

        now = baseNow.addingTimeInterval(15)
        engine.completeActiveReminder()
        XCTAssertNil(engine.activeReminder)
        XCTAssertEqual(store.settings.states[.hydrate]?.lastCompletedAt, now)

        engine.evaluateNow()
        XCTAssertNil(engine.activeReminder)
    }

    func testPausedRemindersDoNotTriggerOverdueReminder() {
        let (store, defaults, suiteName) = makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        configureSingleHydratePlan(on: store, interval: 10, snooze: 5)

        let now = Date(timeIntervalSince1970: 8_500_000)

        var settings = store.settings
        settings.remindersPaused = true
        settings.states[.hydrate] = ReminderState(
            lastCompletedAt: now.addingTimeInterval(-20 * 60),
            lastTriggeredAt: nil,
            snoozedUntil: nil
        )
        store.settings = settings

        let engine = ReminderEngine(settingsStore: store, nowProvider: { now })
        engine.evaluateNow()

        XCTAssertNil(engine.activeReminder)
        XCTAssertNil(store.settings.states[.hydrate]?.lastTriggeredAt)
    }

    func testUnpausingAllowsOverdueReminderToTrigger() {
        let (store, defaults, suiteName) = makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        configureSingleHydratePlan(on: store, interval: 10, snooze: 5)

        let now = Date(timeIntervalSince1970: 8_600_000)

        var settings = store.settings
        settings.remindersPaused = true
        settings.states[.hydrate] = ReminderState(
            lastCompletedAt: now.addingTimeInterval(-20 * 60),
            lastTriggeredAt: nil,
            snoozedUntil: nil
        )
        store.settings = settings

        let engine = ReminderEngine(settingsStore: store, nowProvider: { now })
        engine.evaluateNow()
        XCTAssertNil(engine.activeReminder)

        settings = store.settings
        settings.remindersPaused = false
        store.settings = settings
        engine.evaluateNow()

        XCTAssertEqual(engine.activeReminder, .hydrate)
        XCTAssertEqual(store.settings.states[.hydrate]?.lastTriggeredAt, now)
    }

    func testPausingClearsActiveReminderImmediately() {
        let (store, defaults, suiteName) = makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        configureSingleHydratePlan(on: store, interval: 10, snooze: 5)

        let now = Date(timeIntervalSince1970: 8_700_000)

        var settings = store.settings
        settings.states[.hydrate] = ReminderState(
            lastCompletedAt: now.addingTimeInterval(-20 * 60),
            lastTriggeredAt: nil,
            snoozedUntil: nil
        )
        store.settings = settings

        let engine = ReminderEngine(settingsStore: store, nowProvider: { now })
        engine.evaluateNow()
        XCTAssertEqual(engine.activeReminder, .hydrate)

        settings = store.settings
        settings.remindersPaused = true
        store.settings = settings
        engine.evaluateNow()

        XCTAssertNil(engine.activeReminder)
    }

    func testZeroCooldownAllowsImmediateNextReminder() {
        let (store, defaults, suiteName) = makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        configureHydrateAndStandPlans(on: store, interval: 10, hydrateSnooze: 5, standSnooze: 10)

        let baseNow = Date(timeIntervalSince1970: 9_000_000)
        var now = baseNow

        var settings = store.settings
        settings.interReminderCooldownMinutes = 0
        settings.states[.hydrate] = ReminderState(
            lastCompletedAt: baseNow.addingTimeInterval(-20 * 60),
            lastTriggeredAt: nil,
            snoozedUntil: nil
        )
        settings.states[.stand] = ReminderState(
            lastCompletedAt: baseNow.addingTimeInterval(-20 * 60),
            lastTriggeredAt: nil,
            snoozedUntil: nil
        )
        store.settings = settings

        let engine = ReminderEngine(settingsStore: store, nowProvider: { now })
        engine.evaluateNow()
        XCTAssertEqual(engine.activeReminder, .hydrate)

        now = baseNow.addingTimeInterval(30)
        engine.completeActiveReminder()
        engine.evaluateNow()

        XCTAssertEqual(engine.activeReminder, .stand)
    }

    func testDisablingCooldownDuringWindowAllowsImmediateTrigger() {
        let (store, defaults, suiteName) = makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        configureHydrateAndStandPlans(on: store, interval: 10, hydrateSnooze: 5, standSnooze: 10)

        let baseNow = Date(timeIntervalSince1970: 10_000_000)
        var now = baseNow

        var settings = store.settings
        settings.interReminderCooldownMinutes = 2
        settings.states[.hydrate] = ReminderState(
            lastCompletedAt: baseNow.addingTimeInterval(-20 * 60),
            lastTriggeredAt: nil,
            snoozedUntil: nil
        )
        settings.states[.stand] = ReminderState(
            lastCompletedAt: baseNow.addingTimeInterval(-20 * 60),
            lastTriggeredAt: nil,
            snoozedUntil: nil
        )
        store.settings = settings

        let engine = ReminderEngine(settingsStore: store, nowProvider: { now })
        engine.evaluateNow()
        XCTAssertEqual(engine.activeReminder, .hydrate)

        now = baseNow.addingTimeInterval(20)
        engine.completeActiveReminder()
        engine.evaluateNow()
        XCTAssertNil(engine.activeReminder)

        settings = store.settings
        settings.interReminderCooldownMinutes = 0
        store.settings = settings
        engine.evaluateNow()

        XCTAssertEqual(engine.activeReminder, .stand)
    }
}
