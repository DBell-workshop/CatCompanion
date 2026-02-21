import Foundation
import Combine

@MainActor
public final class ReminderEngine: ObservableObject {
    @Published public private(set) var activeReminder: ReminderType?
    @Published public private(set) var activeSince: Date?

    private let settingsStore: SettingsStore
    private let nowProvider: () -> Date
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let checkInterval: TimeInterval = 30
    private let autoDismissMinutes: Int = 5
    private let overrideInterReminderCooldownMinutes: Int?
    private var interReminderCooldownUntil: Date?

    public init(
        settingsStore: SettingsStore,
        nowProvider: @escaping () -> Date = Date.init,
        interReminderCooldownMinutes: Int? = nil
    ) {
        self.settingsStore = settingsStore
        self.nowProvider = nowProvider
        self.overrideInterReminderCooldownMinutes = interReminderCooldownMinutes
        observeSettings()
    }

    public func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.evaluateNow()
            }
        }
        evaluateNow()
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func evaluateNow() {
        tick(at: nowProvider())
    }

    /// Returns the nearest upcoming reminder type and its due date, or nil if paused/none scheduled.
    public func nextReminderInfo() -> (type: ReminderType, due: Date)? {
        let now = nowProvider()
        guard !settingsStore.settings.remindersPaused else { return nil }
        var nearest: (type: ReminderType, due: Date)?
        for type in ReminderType.allCases {
            guard let plan = settingsStore.settings.plans[type], plan.enabled else { continue }
            let state = settingsStore.settings.states[type] ?? ReminderState()
            guard let due = ReminderSchedule.nextDueDate(for: type, plan: plan, state: state, now: now) else { continue }
            if nearest == nil || due < nearest!.due {
                nearest = (type, due)
            }
        }
        return nearest
    }

    public func completeActiveReminder() {
        guard let type = activeReminder else { return }
        completeReminder(type)
    }

    public func completeReminder(_ type: ReminderType) {
        let now = nowProvider()
        updateState(for: type) { state in
            state.lastCompletedAt = now
            state.snoozedUntil = nil
        }
        applyInterReminderCooldown(from: now)
        if activeReminder == type {
            clearActiveReminder()
        }
    }

    public func snoozeActiveReminder() {
        guard let type = activeReminder else { return }
        snoozeReminder(type)
    }

    public func snoozeReminder(_ type: ReminderType) {
        let now = nowProvider()
        let plan = settingsStore.settings.plans[type] ?? defaultPlan(for: type)
        updateState(for: type) { state in
            state.snoozedUntil = Calendar.current.date(byAdding: .minute, value: plan.snoozeMinutes, to: now)
        }
        applyInterReminderCooldown(from: now)
        if activeReminder == type {
            clearActiveReminder()
        }
    }

    public func dismissActiveReminder() {
        guard let type = activeReminder else { return }
        let now = nowProvider()
        updateState(for: type) { state in
            state.snoozedUntil = Calendar.current.date(byAdding: .minute, value: defaultPlan(for: type).snoozeMinutes, to: now)
        }
        applyInterReminderCooldown(from: now)
        clearActiveReminder()
    }

    private func observeSettings() {
        settingsStore.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.evaluateNow()
            }
            .store(in: &cancellables)
    }

    private func tick(at now: Date) {
        if settingsStore.settings.remindersPaused {
            if activeReminder != nil {
                clearActiveReminder()
            }
            return
        }

        if let activeSince, activeReminder != nil {
            let minutes = Int(now.timeIntervalSince(activeSince) / 60)
            if minutes >= autoDismissMinutes {
                snoozeActiveReminder()
            }
            return
        }

        if currentInterReminderCooldownMinutes() <= 0 {
            interReminderCooldownUntil = nil
        }

        if let cooldownUntil = interReminderCooldownUntil {
            if cooldownUntil > now {
                return
            }
            interReminderCooldownUntil = nil
        }

        var nextDue: (type: ReminderType, date: Date)?
        for type in ReminderType.allCases {
            guard let plan = settingsStore.settings.plans[type] else { continue }
            let state = settingsStore.settings.states[type] ?? ReminderState()
            guard let due = ReminderSchedule.nextDueDate(for: type, plan: plan, state: state, now: now) else { continue }
            if due <= now {
                if nextDue == nil || due < nextDue!.date {
                    nextDue = (type, due)
                }
            }
        }

        if let due = nextDue {
            trigger(type: due.type, at: now)
        }
    }

    private func trigger(type: ReminderType, at date: Date) {
        updateState(for: type) { state in
            state.lastTriggeredAt = date
        }
        activeReminder = type
        activeSince = date
    }

    private func clearActiveReminder() {
        activeReminder = nil
        activeSince = nil
    }

    private func updateState(for type: ReminderType, mutate: (inout ReminderState) -> Void) {
        var settings = settingsStore.settings
        var state = settings.states[type] ?? ReminderState()
        mutate(&state)
        settings.states[type] = state
        settingsStore.settings = settings
    }

    private func defaultPlan(for type: ReminderType) -> ReminderPlan {
        settingsStore.settings.plans[type] ?? ReminderPlan(
            enabled: true,
            intervalMinutes: type.defaultIntervalMinutes,
            quietHours: QuietHours(),
            snoozeMinutes: type.defaultSnoozeMinutes
        )
    }

    private func applyInterReminderCooldown(from now: Date) {
        let cooldownMinutes = currentInterReminderCooldownMinutes()
        guard cooldownMinutes > 0 else {
            interReminderCooldownUntil = nil
            return
        }
        interReminderCooldownUntil = Calendar.current.date(
            byAdding: .minute,
            value: cooldownMinutes,
            to: now
        )
    }

    private func currentInterReminderCooldownMinutes() -> Int {
        let configured = overrideInterReminderCooldownMinutes ?? settingsStore.settings.interReminderCooldownMinutes
        return max(0, configured)
    }
}
