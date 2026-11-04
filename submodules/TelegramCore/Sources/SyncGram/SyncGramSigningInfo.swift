import Foundation

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

    /// Only records the first launch so settings can show the expiry date. No notifications are
    /// scheduled any more: local reminders were removed by request.
    public func registerLaunch() {
        let _ = self.firstLaunchDate
    }
}