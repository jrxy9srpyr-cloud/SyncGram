import Foundation

/// Local-only SyncGram switches. Stored in the standard defaults of the main app
/// process; no data is sent to Telegram or any third party.
public enum SyncGramSettings {
    private enum Key {
        static let ghostMode = "syncgram.ghostMode"
        static let bypassCopyProtection = "syncgram.bypassCopyProtection"
        static let allowSecretScreenshots = "syncgram.allowSecretScreenshots"
        static let keepBlockedChats = "syncgram.keepBlockedChats"
        static let hideOnlineStatus = "syncgram.hideOnlineStatus"
        static let chatListScale = "syncgram.chatListScale"
    }

    private static var defaults: UserDefaults {
        return UserDefaults.standard
    }

    public static var ghostModeEnabled: Bool {
        get { return defaults.bool(forKey: Key.ghostMode) }
        set { defaults.set(newValue, forKey: Key.ghostMode) }
    }

    public static var bypassCopyProtectionEnabled: Bool {
        get { return defaults.bool(forKey: Key.bypassCopyProtection) }
        set { defaults.set(newValue, forKey: Key.bypassCopyProtection) }
    }

    public static var allowSecretScreenshots: Bool {
        get { return defaults.bool(forKey: Key.allowSecretScreenshots) }
        set { defaults.set(newValue, forKey: Key.allowSecretScreenshots) }
    }

    public static var keepBlockedChatsEnabled: Bool {
        get { return defaults.bool(forKey: Key.keepBlockedChats) }
        set { defaults.set(newValue, forKey: Key.keepBlockedChats) }
    }

    public static var hideOnlineStatusEnabled: Bool {
        get { return defaults.bool(forKey: Key.hideOnlineStatus) }
        set { defaults.set(newValue, forKey: Key.hideOnlineStatus) }
    }

    /// 1.0 is the system size. Values below 1.0 make the chat list more compact.
    public static var chatListScale: Double {
        get {
            if defaults.object(forKey: Key.chatListScale) == nil {
                return 1.0
            }
            return min(1.0, max(0.6, defaults.double(forKey: Key.chatListScale)))
        }
        set { defaults.set(min(1.0, max(0.6, newValue)), forKey: Key.chatListScale) }
    }
}
