import Foundation
import UserNotifications

/// Schedules and manages local notifications for class start reminders.
/// Notifications fire 5 minutes before each scheduled class, repeating weekly.
class NotificationService {
    static let shared = NotificationService()
    private init() {}

    private let notificationIdPrefix = "sponge-class-reminder"

    // MARK: - Authorization

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("NotificationService: Authorization error: \(error)")
            }
            print("NotificationService: Authorization granted=\(granted)")
        }
    }

    // MARK: - Scheduling

    /// Cancels all existing class reminders and reschedules from the given class list.
    /// Call this whenever classes are added, updated, or deleted.
    func rescheduleAll(for classes: [SDClass]) {
        // Remove all previously scheduled class reminders
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix(self.notificationIdPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }

        // Schedule new reminders for all classes that have a schedule
        for classModel in classes where classModel.hasSchedule {
            scheduleReminders(for: classModel)
        }
    }

    private func scheduleReminders(for classModel: SDClass) {
        let center = UNUserNotificationCenter.current()

        for dayBit in SDClass.dayBits {
            guard classModel.scheduleDaysMask & dayBit.weekday != 0 else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Time to record — \(classModel.name)"
            content.body = "Your class starts in 5 minutes. Open Sponge to start recording."
            content.sound = .default

            // Notification fires 5 minutes before class start
            let reminderMinute = classModel.scheduleStartMinute - 5
            var components = DateComponents()
            components.weekday = weekdayIndex(for: dayBit.weekday)
            components.hour = max(0, reminderMinute / 60)
            components.minute = max(0, reminderMinute % 60)

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let id = "\(notificationIdPrefix)-\(classModel.id)-day\(dayBit.weekday)"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

            center.add(request) { error in
                if let error = error {
                    print("NotificationService: Failed to schedule for \(classModel.name) on \(dayBit.label): \(error)")
                }
            }
        }

        print("NotificationService: Scheduled reminders for \(classModel.name)")
    }

    // MARK: - Weekday Mapping

    /// Maps SDClass bitmask (Sun=1, Mon=2, Tue=4, Wed=8, Thu=16, Fri=32, Sat=64)
    /// to UNCalendarNotificationTrigger weekday index (1=Sun … 7=Sat).
    private func weekdayIndex(for bitmask: Int) -> Int {
        switch bitmask {
        case 1:  return 1 // Sun
        case 2:  return 2 // Mon
        case 4:  return 3 // Tue
        case 8:  return 4 // Wed
        case 16: return 5 // Thu
        case 32: return 6 // Fri
        case 64: return 7 // Sat
        default: return 1
        }
    }
}
