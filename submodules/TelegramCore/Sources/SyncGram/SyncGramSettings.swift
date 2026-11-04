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
        static let hideReadReceipts = "syncgram.hideReadReceipts"
        static let hideTyping = "syncgram.hideTyping"
        static let hideStoryViews = "syncgram.hideStoryViews"
        static let hideAds = "syncgram.hideAds"
        static let flipToHide = "syncgram.flipToHide"
        static let backgroundRefresh = "syncgram.backgroundRefresh"
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

    public static var hideReadReceiptsEnabled: Bool {
        get { return defaults.bool(forKey: Key.hideReadReceipts) }
        set { defaults.set(newValue, forKey: Key.hideReadReceipts) }
    }

    public static var hideTypingEnabled: Bool {
        get { return defaults.bool(forKey: Key.hideTyping) }
        set { defaults.set(newValue, forKey: Key.hideTyping) }
    }

    public static var hideStoryViewsEnabled: Bool {
        get { return defaults.bool(forKey: Key.hideStoryViews) }
        set { defaults.set(newValue, forKey: Key.hideStoryViews) }
    }

    public static var hideAdsEnabled: Bool {
        get { return defaults.bool(forKey: Key.hideAds) }
        set { defaults.set(newValue, forKey: Key.hideAds) }
    }

    public static var flipToHideEnabled: Bool {
        get { return defaults.bool(forKey: Key.flipToHide) }
        set { defaults.set(newValue, forKey: Key.flipToHide) }
    }

    public static var backgroundRefreshEnabled: Bool {
        get {
            if defaults.object(forKey: Key.backgroundRefresh) == nil {
                return true
            }
            return defaults.bool(forKey: Key.backgroundRefresh)
        }
        set { defaults.set(newValue, forKey: Key.backgroundRefresh) }
    }

    /// Settings included in the portable session backup. Kept as strings so the file format stays
    /// forward compatible when new switches are added.
    public static func sessionSnapshot() -> [String: String] {
        return [
            "ghostMode": self.ghostModeEnabled ? "1" : "0",
            "hideOnline": self.hideOnlineStatusEnabled ? "1" : "0",
            "hideReads": self.hideReadReceiptsEnabled ? "1" : "0",
            "hideTyping": self.hideTypingEnabled ? "1" : "0",
            "hideStories": self.hideStoryViewsEnabled ? "1" : "0",
            "copyProtection": self.bypassCopyProtectionEnabled ? "1" : "0",
            "screenshots": self.allowSecretScreenshots ? "1" : "0",
            "blockedChats": self.keepBlockedChatsEnabled ? "1" : "0",
            "hideAds": self.hideAdsEnabled ? "1" : "0",
            "flipToHide": self.flipToHideEnabled ? "1" : "0",
            "backgroundRefresh": self.backgroundRefreshEnabled ? "1" : "0",
            "chatListScale": String(self.chatListScale)
        ]
    }

    /// Applies a snapshot produced by `sessionSnapshot()`. Unknown keys are ignored, so an older
    /// build can import a file written by a newer one.
    public static func applySessionSnapshot(_ values: [String: String]) {
        func flag(_ key: String) -> Bool? {
            guard let raw = values[key] else {
                return nil
            }
            return raw == "1" || raw.lowercased() == "true"
        }
        if let value = flag("ghostMode") { self.ghostModeEnabled = value }
        if let value = flag("hideOnline") { self.hideOnlineStatusEnabled = value }
        if let value = flag("hideReads") { self.hideReadReceiptsEnabled = value }
        if let value = flag("hideTyping") { self.hideTypingEnabled = value }
        if let value = flag("hideStories") { self.hideStoryViewsEnabled = value }
        if let value = flag("copyProtection") { self.bypassCopyProtectionEnabled = value }
        if let value = flag("screenshots") { self.allowSecretScreenshots = value }
        if let value = flag("blockedChats") { self.keepBlockedChatsEnabled = value }
        if let value = flag("hideAds") { self.hideAdsEnabled = value }
        if let value = flag("flipToHide") { self.flipToHideEnabled = value }
        if let value = flag("backgroundRefresh") { self.backgroundRefreshEnabled = value }
        if let raw = values["chatListScale"], let scale = Double(raw) {
            self.chatListScale = scale
        }
    }

    /// 1.0 is the system size. Values below 1.0 make the chat list more compact.
    public static var chatListScale: Double {
        get {
            if defaults.object(forKey: Key.chatListScale) == nil {
                return 1.0
            }
            return min(1.0, max(0.6, defaults.double(forKey: Key.chatListScale)))
        }
        set {
            let value = min(1.0, max(0.6, newValue))
            defaults.set(value, forKey: Key.chatListScale)
            SyncGramChatListMetrics.scale = value
        }
    }
}

/// Names of the local notifications used to propagate SyncGram setting changes between modules.
public enum SyncGramNotificationNames {
    public static let hideOnlineChanged = Notification.Name("SyncGramHideOnlineChanged")
    public static let chatListScaleChanged = Notification.Name("SyncGramChatListScaleChanged")
    public static let navigationChanged = Notification.Name("SyncGramNavigationChanged")
    public static let flipToHideChanged = Notification.Name("SyncGramFlipToHideChanged")
    public static let settingsChanged = Notification.Name("SyncGramSettingsChanged")
}

/// Cached chat list scale, so the row layout does not read UserDefaults on every access.
public enum SyncGramChatListMetrics {
    public static var scale: Double = SyncGramSettings.chatListScale
}
