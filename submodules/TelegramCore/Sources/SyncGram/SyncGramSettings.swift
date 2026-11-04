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
        static let deletedNotifications = "syncgram.deletedNotifications"
        static let signingNotifications = "syncgram.signingNotifications"
        static let chatListScale = "syncgram.chatListScale"
        static let localPremium = "syncgram.localPremium"
        static let localPremiumPreviousHideAds = "syncgram.localPremium.previousHideAds"
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

    public static var deletedMessageNotificationsEnabled: Bool {
        get { return defaults.bool(forKey: Key.deletedNotifications) }
        set { defaults.set(newValue, forKey: Key.deletedNotifications) }
    }

    public static var signingNotificationsEnabled: Bool {
        get {
            if defaults.object(forKey: Key.signingNotifications) == nil {
                return true
            }
            return defaults.bool(forKey: Key.signingNotifications)
        }
        set { defaults.set(newValue, forKey: Key.signingNotifications) }
    }

    /// Local cosmetic "premium" state. It does not change the Telegram account in any way.
    public static var localPremiumEnabled: Bool {
        get { return defaults.bool(forKey: Key.localPremium) }
        set { defaults.set(newValue, forKey: Key.localPremium) }
    }

    /// The value of `hideAdsEnabled` before the local premium turned it on, so turning the
    /// premium off can restore the user's previous choice.
    public static var localPremiumPreviousHideAds: Bool? {
        get {
            if defaults.object(forKey: Key.localPremiumPreviousHideAds) == nil {
                return nil
            }
            return defaults.bool(forKey: Key.localPremiumPreviousHideAds)
        }
        set {
            if let value = newValue {
                defaults.set(value, forKey: Key.localPremiumPreviousHideAds)
            } else {
                defaults.removeObject(forKey: Key.localPremiumPreviousHideAds)
            }
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
public enum SyncGramNotifications {
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
