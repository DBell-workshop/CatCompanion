import Foundation
import UserNotifications
import CatCompanionCore

enum NotificationAction {
    case open
    case complete
    case snooze
}

@MainActor
protocol NotificationManagerDelegate: AnyObject {
    func notificationManager(
        _ manager: NotificationManager,
        didReceive action: NotificationAction,
        reminderType: ReminderType?
    )
}

final class NotificationManager: NSObject {
    static let reminderCategoryIdentifier = "catcompanion.reminder"
    static let reminderTypeKey = "reminderType"
    private static let completeActionIdentifier = "catcompanion.action.complete"
    private static let snoozeActionIdentifier = "catcompanion.action.snooze"

    weak var delegate: NotificationManagerDelegate?

    private let center: UNUserNotificationCenter

    override init() {
        self.center = UNUserNotificationCenter.current()
        super.init()
        center.delegate = self
        registerCategories()
    }

    func requestAuthorizationIfNeeded(completion: ((Bool) -> Void)? = nil) {
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                completion?(true)
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    completion?(granted)
                }
            case .denied:
                completion?(false)
            @unknown default:
                completion?(false)
            }
        }
    }

    func sendNotification(for reminder: ReminderType) {
        requestAuthorizationIfNeeded { [weak self] granted in
            guard let self, granted else { return }

            let content = UNMutableNotificationContent()
            content.title = reminder.displayName
            content.body = reminder.prompt
            content.sound = .default
            content.categoryIdentifier = Self.reminderCategoryIdentifier
            content.userInfo = [Self.reminderTypeKey: reminder.rawValue]

            let request = UNNotificationRequest(
                identifier: "catcompanion-\(reminder.rawValue)-\(Date().timeIntervalSince1970)",
                content: content,
                trigger: nil
            )
            self.center.add(request)
        }
    }

    private func registerCategories() {
        let complete = UNNotificationAction(
            identifier: Self.completeActionIdentifier,
            title: AppStrings.text(.actionComplete),
            options: []
        )
        let snooze = UNNotificationAction(
            identifier: Self.snoozeActionIdentifier,
            title: AppStrings.text(.actionSnooze),
            options: []
        )

        let category = UNNotificationCategory(
            identifier: Self.reminderCategoryIdentifier,
            actions: [complete, snooze],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    private func reminderType(from userInfo: [AnyHashable: Any]) -> ReminderType? {
        guard let raw = userInfo[Self.reminderTypeKey] as? String else { return nil }
        return ReminderType(rawValue: raw)
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let reminder = reminderType(from: response.notification.request.content.userInfo)
        let action: NotificationAction
        switch response.actionIdentifier {
        case Self.completeActionIdentifier:
            action = .complete
        case Self.snoozeActionIdentifier:
            action = .snooze
        default:
            action = .open
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.notificationManager(self, didReceive: action, reminderType: reminder)
        }
        completionHandler()
    }
}
