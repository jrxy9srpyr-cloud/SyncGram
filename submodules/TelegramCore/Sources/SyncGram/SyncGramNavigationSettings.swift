import Foundation

public enum SyncGramTabPlacement: String {
    case bottom
    case top
    case swipe
    case hidden
}

public enum SyncGramTabId: String, CaseIterable {
    case chats
    case contacts
    case calls
    case news
    case settings

    public var title: String {
        switch self {
        case .chats:
            return "Чаты"
        case .contacts:
            return "Контакты"
        case .calls:
            return "Звонки"
        case .news:
            return "Новости"
        case .settings:
            return "Настройки"
        }
    }
}

public final class SyncGramNavigationSettings {
    public static let shared = SyncGramNavigationSettings()

    private enum Key {
        static let placements = "syncgram.navigation.placements"
    }

    private let defaults = UserDefaults.standard

    private init() {
    }

    public var placements: [String: String] {
        get {
            return self.defaults.dictionary(forKey: Key.placements) as? [String: String] ?? [:]
        }
        set {
            self.defaults.set(newValue, forKey: Key.placements)
        }
    }

    public func placement(for tab: SyncGramTabId) -> SyncGramTabPlacement {
        if let raw = self.placements[tab.rawValue], let value = SyncGramTabPlacement(rawValue: raw) {
            return value
        }
        switch tab {
        case .chats, .contacts, .settings:
            return .bottom
        case .calls, .news:
            return .bottom
        }
    }

    public func setPlacement(_ placement: SyncGramTabPlacement, for tab: SyncGramTabId) {
        var values = self.placements
        values[tab.rawValue] = placement.rawValue
        self.placements = values
    }

    public var bottomTabs: [SyncGramTabId] {
        return SyncGramTabId.allCases.filter { self.placement(for: $0) == .bottom }
    }

    public var swipeTabs: [SyncGramTabId] {
        return SyncGramTabId.allCases.filter { self.placement(for: $0) == .swipe }
    }

    public var topTabs: [SyncGramTabId] {
        return SyncGramTabId.allCases.filter { self.placement(for: $0) == .top }
    }
}