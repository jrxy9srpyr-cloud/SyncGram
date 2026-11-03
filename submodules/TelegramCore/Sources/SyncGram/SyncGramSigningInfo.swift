import Foundation
import UserNotifications

public final class SyncGramSigningInfo {
    public static let shared = SyncGramSigningInfo()

    private let defaults = UserDefaults.standard
    private let firstLaunchKey = "syncgram.signing.firstLaunch"
    private let notificationPrefix = "syncgram.signing.expiry"

    private init() {
    }

    public var firstLaunchDate: Date {
        if let value = self.defaults.object(forKey: self.firstLaunchKey) as? Double, value > 0 {
            return Date(timeIntervalSince1970: value)
        }
        let date = Date()
        self.defaults.set(date.timeIntervalSince1970, forKey: self.firstLaunchKey)
        return date
    }

    /// Free Apple ID signatures are valid for 7 days.
    public var expiryDate: Date {
        return self.firstLaunchDate.addingTimeInterval(7.0 * 24.0 * 60.0 * 60.0)
    }

    public var daysRemaining: Int {
        return max(0, Int(ceil(self.expiryDate.timeIntervalSinceNow / (24.0 * 60.0 * 60.0))))
    }

    public func registerLaunch() {
        let _ = self.firstLaunchDate
        self.scheduleNotificationsIfNeeded()
    }

    public func scheduleNotificationsIfNeeded() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "\(self.notificationPrefix).day",
            "\(self.notificationPrefix).now"
        ])
        guard SyncGramSettings.signingNotificationsEnabled else {
            return
        }
        let calendar = Calendar.current
        let dates: [(String, Date, String)] = [
            ("day", self.expiryDate.addingTimeInterval(-24.0 * 60.0 * 60.0), "Подпись SyncGram истекает завтра. Переподпиши приложение."),
            ("now", self.expiryDate, "Срок подписи SyncGram истёк. Переподпиши приложение, иначе оно перестанет запускаться.")
        ]
        for (suffix, date, text) in dates {
            if date <= Date() {
                continue
            }
            let content = UNMutableNotificationContent()
            content.title = "Срок подписи SyncGram"
            content.body = text
            content.sound = .default
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            components.second = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: "\(self.notificationPrefix).\(suffix)", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        }
    }
}