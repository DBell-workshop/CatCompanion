import Foundation

public enum ReminderSchedule {
    public static func nextDueDate(
        for type: ReminderType,
        plan: ReminderPlan,
        state: ReminderState,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        guard plan.enabled, plan.intervalMinutes > 0 else { return nil }

        if let snoozedUntil = state.snoozedUntil, snoozedUntil > now {
            return adjustForQuietHours(snoozedUntil, quietHours: plan.quietHours, calendar: calendar)
        }

        let base = state.lastCompletedAt ?? state.lastTriggeredAt ?? now
        let rawDue = calendar.date(byAdding: .minute, value: plan.intervalMinutes, to: base) ?? now
        let normalized = rawDue < now ? now : rawDue
        return adjustForQuietHours(normalized, quietHours: plan.quietHours, calendar: calendar)
    }

    public static func isInQuietHours(
        _ date: Date,
        quietHours: QuietHours,
        calendar: Calendar = .current
    ) -> Bool {
        if quietHours.isDisabled { return false }
        let hour = calendar.component(.hour, from: date)
        let start = quietHours.startHour
        let end = quietHours.endHour

        if start < end {
            return hour >= start && hour < end
        }
        if start > end {
            return hour >= start || hour < end
        }
        return false
    }

    public static func adjustForQuietHours(
        _ date: Date,
        quietHours: QuietHours,
        calendar: Calendar = .current
    ) -> Date {
        guard isInQuietHours(date, quietHours: quietHours, calendar: calendar) else { return date }

        let start = quietHours.startHour
        let end = quietHours.endHour

        if start < end {
            let endToday = calendar.date(bySettingHour: end, minute: 0, second: 0, of: date) ?? date
            if date < endToday { return endToday }
            return calendar.date(byAdding: .day, value: 1, to: endToday) ?? endToday
        }

        if start > end {
            let hour = calendar.component(.hour, from: date)
            if hour >= start {
                let endTomorrow = calendar.date(bySettingHour: end, minute: 0, second: 0, of: date) ?? date
                return calendar.date(byAdding: .day, value: 1, to: endTomorrow) ?? endTomorrow
            }
            let endToday = calendar.date(bySettingHour: end, minute: 0, second: 0, of: date) ?? date
            return endToday
        }

        return date
    }
}
