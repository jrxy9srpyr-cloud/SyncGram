import Foundation

public final class SyncGramAccountSettings {
    public static let shared = SyncGramAccountSettings()

    private let defaults = UserDefaults.standard

    private init() {
    }

    private func key(_ suffix: String, _ id: Int64) -> String {
        return "syncgram.account.\(suffix).\(id)"
    }

    public func colorIndex(for id: Int64) -> Int {
        return self.defaults.integer(forKey: self.key("color", id))
    }

    public func setColorIndex(_ value: Int, for id: Int64) {
        self.defaults.set(value, forKey: self.key("color", id))
    }

    public func emoji(for id: Int64) -> String {
        return self.defaults.string(forKey: self.key("emoji", id)) ?? ""
    }

    public func setEmoji(_ value: String, for id: Int64) {
        self.defaults.set(value, forKey: self.key("emoji", id))
    }

    public func mutedUntil(for id: Int64) -> Date? {
        let value = self.defaults.double(forKey: self.key("mutedUntil", id))
        if value <= 0 {
            return nil
        }
        return Date(timeIntervalSince1970: value)
    }

    public func setMutedUntil(_ date: Date?, for id: Int64) {
        if let date {
            self.defaults.set(date.timeIntervalSince1970, forKey: self.key("mutedUntil", id))
        } else {
            self.defaults.removeObject(forKey: self.key("mutedUntil", id))
        }
    }

    public func lastActivity(for id: Int64) -> Date? {
        let value = self.defaults.double(forKey: self.key("lastActivity", id))
        if value <= 0 {
            return nil
        }
        return Date(timeIntervalSince1970: value)
    }

    public func markActivity(for id: Int64) {
        self.defaults.set(Date().timeIntervalSince1970, forKey: self.key("lastActivity", id))
    }
}