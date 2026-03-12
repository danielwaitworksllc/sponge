import Foundation
import UserNotifications

/// Schedules and manages local notifications for class start reminders.
/// Notifications fire before each scheduled class, repeating weekly.
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

    /// Snapshot of class data needed for scheduling, captured on the main actor.
    private struct ClassSnapshot {
        let id: UUID
        let name: String
        let scheduleDaysMask: Int
        let scheduleStartMinute: Int
    }

    /// Cancels all existing class reminders and reschedules from the given class list.
    /// Respects user preferences for enabled state and lead time.
    /// Must be called from the main actor (classes are SwiftData models).
    func rescheduleAll(for classes: [SDClass]) {
        // Snapshot SwiftData model properties on the calling thread (main actor)
        let enabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        let leadMinutes = UserDefaults.standard.object(forKey: "reminderLeadMinutes") as? Int ?? 5

        let snapshots: [ClassSnapshot] = classes
            .filter(\.hasSchedule)
            .map { ClassSnapshot(id: $0.id, name: $0.name, scheduleDaysMask: $0.scheduleDaysMask, scheduleStartMinute: $0.scheduleStartMinute) }

        let center = UNUserNotificationCenter.current()

        // Remove old reminders, then schedule new ones inside the completion handler
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix(self.notificationIdPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)

            guard enabled else {
                print("NotificationService: Notifications disabled by user")
                return
            }

            for snapshot in snapshots {
                self.scheduleReminders(for: snapshot, leadMinutes: leadMinutes)
            }
        }
    }

    /// Removes all pending class reminders.
    func removeAll() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix(self.notificationIdPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
            print("NotificationService: Removed all reminders")
        }
    }

    private func scheduleReminders(for snapshot: ClassSnapshot, leadMinutes: Int) {
        let center = UNUserNotificationCenter.current()

        for dayBit in SDClass.dayBits {
            guard snapshot.scheduleDaysMask & dayBit.weekday != 0 else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Time to record — \(snapshot.name)"
            content.body = "Your class starts in \(leadMinutes) minute\(leadMinutes == 1 ? "" : "s"). Open Sponge to start recording."
            content.sound = .default

            var reminderMinute = snapshot.scheduleStartMinute - leadMinutes
            var weekday = weekdayIndex(for: dayBit.weekday)

            // Handle wrap across midnight (e.g. class at 00:02, lead 5 → 23:57 previous day)
            if reminderMinute < 0 {
                reminderMinute += 1440 // 24 * 60
                weekday = weekday == 1 ? 7 : weekday - 1
            }

            var components = DateComponents()
            components.weekday = weekday
            components.hour = reminderMinute / 60
            components.minute = reminderMinute % 60

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let id = "\(notificationIdPrefix)-\(snapshot.id)-day\(dayBit.weekday)"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

            center.add(request) { error in
                if let error = error {
                    print("NotificationService: Failed to schedule for \(snapshot.name) on \(dayBit.label): \(error)")
                }
            }
        }

        print("NotificationService: Scheduled reminders for \(snapshot.name) (\(leadMinutes)min lead)")
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
