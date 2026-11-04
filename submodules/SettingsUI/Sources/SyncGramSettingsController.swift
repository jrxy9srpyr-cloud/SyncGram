import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext

private enum SyncGramSettingsToggle: Int32 {
    case shader
    case ghostMode
    case hideOnline
    case hideReads
    case hideTyping
    case hideStories
    case copyProtection
    case screenshots
    case blockedChats
    case hideAds
    case flipToHide
    case backgroundRefresh
}

private final class SyncGramSettingsControllerArguments {
    let toggle: (SyncGramSettingsToggle, Bool) -> Void
    let openChatListSize: () -> Void
    let openShaderStyle: () -> Void
    let openSecurityQuestion: () -> Void
    let openNavigation: () -> Void
    let openAccounts: () -> Void
    let openCache: () -> Void
    let openSession: () -> Void
    let readAllChats: () -> Void

    init(toggle: @escaping (SyncGramSettingsToggle, Bool) -> Void, openChatListSize: @escaping () -> Void, openShaderStyle: @escaping () -> Void, openSecurityQuestion: @escaping () -> Void, openNavigation: @escaping () -> Void, openAccounts: @escaping () -> Void, openCache: @escaping () -> Void, openSession: @escaping () -> Void, readAllChats: @escaping () -> Void) {
        self.toggle = toggle
        self.openChatListSize = openChatListSize
        self.openShaderStyle = openShaderStyle
        self.openSecurityQuestion = openSecurityQuestion
        self.openNavigation = openNavigation
        self.openAccounts = openAccounts
        self.openCache = openCache
        self.openSession = openSession
        self.readAllChats = readAllChats
    }
}

private enum SyncGramSettingsSection: Int32 {
    case appearance
    case privacy
    case notifications
    case data
    case actions
    case about
}

private enum SyncGramSettingsEntry: ItemListNodeEntry {
    case appearanceHeader
    case shader(Bool)
    case shaderStyle(String)
    case chatListSize(String)

    case privacyHeader
    case ghostMode(Bool)
    case hideOnline(Bool)
    case hideReads(Bool)
    case hideTyping(Bool)
    case hideStories(Bool)
    case copyProtection(Bool)
    case hideAds(Bool)
    case screenshots(Bool)
    case flipToHide(Bool)
    case blockedChats(Bool)

    case notificationsHeader
    case backgroundRefresh(Bool)

    case dataHeader
    case accounts
    case cache
    case session
    case securityQuestion(String)
    case navigation
    case signingInfo(String)

    case actionsHeader
    case readAll

    case footer

    var section: ItemListSectionId {
        switch self {
        case .appearanceHeader, .shader, .shaderStyle, .chatListSize:
            return SyncGramSettingsSection.appearance.rawValue
        case .privacyHeader, .ghostMode, .hideOnline, .hideReads, .hideTyping, .hideStories, .copyProtection, .hideAds, .screenshots, .flipToHide, .blockedChats:
            return SyncGramSettingsSection.privacy.rawValue
        case .notificationsHeader, .backgroundRefresh:
            return SyncGramSettingsSection.notifications.rawValue
        case .dataHeader, .accounts, .cache, .session, .securityQuestion, .navigation, .signingInfo:
            return SyncGramSettingsSection.data.rawValue
        case .actionsHeader, .readAll:
            return SyncGramSettingsSection.actions.rawValue
        case .footer:
            return SyncGramSettingsSection.about.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .appearanceHeader:
            return 0
        case .shader:
            return 1
        case .shaderStyle:
            return 2
        case .chatListSize:
            return 3

        case .privacyHeader:
            return 4
        case .ghostMode:
            return 5
        case .hideOnline:
            return 6
        case .hideReads:
            return 7
        case .hideTyping:
            return 8
        case .hideStories:
            return 9
        case .copyProtection:
            return 10
        case .hideAds:
            return 11
        case .screenshots:
            return 12
        case .flipToHide:
            return 13
        case .blockedChats:
            return 14

        case .notificationsHeader:
            return 15
        case .backgroundRefresh:
            return 16

        case .dataHeader:
            return 17
        case .accounts:
            return 18
        case .cache:
            return 19
        case .session:
            return 20
        case .securityQuestion:
            return 21
        case .navigation:
            return 22
        case .signingInfo:
            return 23

        case .actionsHeader:
            return 24
        case .readAll:
            return 25

        case .footer:
            return 26
        }
    }

    static func <(lhs: SyncGramSettingsEntry, rhs: SyncGramSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! SyncGramSettingsControllerArguments
        switch self {
        case .appearanceHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "Внешний вид", sectionId: self.section)
        case let .shader(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Живой фон", text: "Анимированный узор за списком чатов, в чатах и в настройках. Работает локально и почти не расходует батарею.", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(.shader, value)
            })
        case let .shaderStyle(value):
            return ItemListDisclosureItem(presentationData: presentationData, title: "Стиль фона", enabled: SyncGramSettings.shaderEnabled, label: value, sectionId: self.section, style: .blocks, action: {
                arguments.openShaderStyle()
            })
        case let .chatListSize(value):
            return ItemListDisclosureItem(presentationData: presentationData, title: "Размер списка чатов", label: value, sectionId: self.section, style: .blocks, action: {
                arguments.openChatListSize()
            })

        case .privacyHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "Приватность", sectionId: self.section)
        case let .ghostMode(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Хранить удалённые сообщения", text: "Сохраняет удалённые сообщения локально и помечает их.", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(.ghostMode, value)
            })
        case let .hideOnline(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Не показывать «онлайн»", text: "Не отправляет собеседникам статус «онлайн».", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(.hideOnline, value)
            })
        case let .hideReads(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Не отправлять прочтение", text: "Сообщения остаются непрочитанными для собеседника.", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(.hideReads, value)
            })
        case let .hideTyping(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Не показывать набор текста", text: "Скрывает «печатает…» и выбор стикеров.", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(.hideTyping, value)
            })
        case let .hideStories(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Не отмечать просмотр Stories", text: "Не отправляет отметку о просмотре Stories.", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(.hideStories, value)
            })
        case let .copyProtection(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Обход защиты от копирования", text: "Разрешает пересылку и сохранение защищённого контента.", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(.copyProtection, value)
            })
        case let .hideAds(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Отключение рекламы", text: "Скрывает рекламные сообщения Telegram.", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(.hideAds, value)
            })
        case let .screenshots(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Скриншоты в секретных чатах", text: "Не блокирует экран и не отправляет уведомление о скриншоте.", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(.screenshots, value)
            })
        case let .flipToHide(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Скрывать экран при перевороте", text: "Прячет имена, аватары и сообщения, когда телефон лежит экраном вниз.", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(.flipToHide, value)
            })
        case let .blockedChats(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Сохранять чаты после блокировки", text: "Оставляет чат доступным после блокировки или бана.", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(.blockedChats, value)
            })

        case .notificationsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "Уведомления", sectionId: self.section)
        case let .backgroundRefresh(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Уведомления в фоне", text: "Иногда проверяет новые сообщения, когда приложение свёрнуто, и показывает локальное уведомление. iOS решает когда; работает без сервера.", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(.backgroundRefresh, value)
            })

        case .dataHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "Данные и аккаунт", sectionId: self.section)
        case .accounts:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Аккаунты", label: "Панель", sectionId: self.section, style: .blocks, action: {
                arguments.openAccounts()
            })
        case .cache:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Умное управление кэшем", label: "Размер и очистка", sectionId: self.section, style: .blocks, action: {
                arguments.openCache()
            })
        case .session:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Сессия аккаунта", label: "Экспорт и импорт", sectionId: self.section, style: .blocks, action: {
                arguments.openSession()
            })
        case let .securityQuestion(value):
            return ItemListDisclosureItem(presentationData: presentationData, title: "Контрольный вопрос", label: value, sectionId: self.section, style: .blocks, action: {
                arguments.openSecurityQuestion()
            })
        case .navigation:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Навигация", label: "Вкладки", sectionId: self.section, style: .blocks, action: {
                arguments.openNavigation()
            })
        case let .signingInfo(value):
            return ItemListDisclosureItem(presentationData: presentationData, title: "Срок подписи", label: value, sectionId: self.section, style: .blocks, action: nil)

        case .actionsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "Действия", sectionId: self.section)
        case .readAll:
            return ItemListActionItem(presentationData: presentationData, title: "Прочитать все чаты", kind: .generic, alignment: .center, sectionId: self.section, style: .blocks, action: {
                arguments.readAllChats()
            })

        case .footer:
            return ItemListTextItem(presentationData: presentationData, text: .markdown("Эти настройки действуют только на этом устройстве. Удалённые сообщения остаются в локальной базе, пересылка и сохранение игнорируют клиентскую защиту, а секретные чаты не отправляют уведомления о скриншотах. Живой фон рисуется на устройстве и никуда не отправляется. Сервер по-прежнему может отклонить действие, если оно запрещено на его стороне."), sectionId: self.section)
        }
    }
}

private func syncGramSettingsEntries() -> [SyncGramSettingsEntry] {
    let signingInfoText: String = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(SyncGramSigningInfo.shared.daysRemaining) дн. (до \(formatter.string(from: SyncGramSigningInfo.shared.expiryDate)))"
    }()
    return syncGramSettingsEntries(signingInfoText: signingInfoText)
}

private func syncGramSettingsEntries(signingInfoText: String) -> [SyncGramSettingsEntry] {
    return [
        .appearanceHeader,
        .shader(SyncGramSettings.shaderEnabled),
        .shaderStyle(SyncGramSettings.shaderStyle.title),
        .chatListSize("\(Int(round(SyncGramSettings.chatListScale * 100.0)))%"),

        .privacyHeader,
        .ghostMode(SyncGramSettings.ghostModeEnabled),
        .hideOnline(SyncGramSettings.hideOnlineStatusEnabled),
        .hideReads(SyncGramSettings.hideReadReceiptsEnabled),
        .hideTyping(SyncGramSettings.hideTypingEnabled),
        .hideStories(SyncGramSettings.hideStoryViewsEnabled),
        .copyProtection(SyncGramSettings.bypassCopyProtectionEnabled),
        .hideAds(SyncGramSettings.hideAdsEnabled),
        .screenshots(SyncGramSettings.allowSecretScreenshots),
        .flipToHide(SyncGramSettings.flipToHideEnabled),
        .blockedChats(SyncGramSettings.keepBlockedChatsEnabled),

        .notificationsHeader,
        .backgroundRefresh(SyncGramSettings.backgroundRefreshEnabled),

        .dataHeader,
        .accounts,
        .cache,
        .session,
        .securityQuestion(SyncGramChatLock.shared.hasSecurityQuestion ? "Задан" : "Не задан"),
        .navigation,
        .signingInfo(signingInfoText),

        .actionsHeader,
        .readAll,

        .footer
    ]
}

private var syncGramSettingsChangeObserver: NSObjectProtocol?

public func syncGramSettingsController(context: AccountContext) -> ViewController {
    let revision = ValuePromise<Int>(0, ignoreRepeated: false)

    if let observer = syncGramSettingsChangeObserver {
        NotificationCenter.default.removeObserver(observer)
    }
    syncGramSettingsChangeObserver = NotificationCenter.default.addObserver(forName: SyncGramNotificationNames.settingsChanged, object: nil, queue: .main, using: { [weak revision] _ in
        revision?.set(0)
    })

    var openChatListSizeImpl: (() -> Void)?
    var openShaderStyleImpl: (() -> Void)?
    var openSecurityQuestionImpl: (() -> Void)?
    var openNavigationImpl: (() -> Void)?
    var openAccountsImpl: (() -> Void)?
    var openCacheImpl: (() -> Void)?
    var openSessionImpl: (() -> Void)?

    let arguments = SyncGramSettingsControllerArguments(toggle: { toggle, value in
        switch toggle {
        case .shader:
            SyncGramSettings.shaderEnabled = value
            NotificationCenter.default.post(name: SyncGramNotificationNames.shaderChanged, object: nil)
        case .ghostMode:
            SyncGramSettings.ghostModeEnabled = value
        case .hideOnline:
            SyncGramSettings.hideOnlineStatusEnabled = value
            NotificationCenter.default.post(name: SyncGramNotificationNames.hideOnlineChanged, object: nil)
        case .hideReads:
            SyncGramSettings.hideReadReceiptsEnabled = value
        case .hideTyping:
            SyncGramSettings.hideTypingEnabled = value
        case .hideStories:
            SyncGramSettings.hideStoryViewsEnabled = value
        case .copyProtection:
            SyncGramSettings.bypassCopyProtectionEnabled = value
        case .screenshots:
            SyncGramSettings.allowSecretScreenshots = value
        case .blockedChats:
            SyncGramSettings.keepBlockedChatsEnabled = value
        case .hideAds:
            SyncGramSettings.hideAdsEnabled = value
        case .flipToHide:
            SyncGramSettings.flipToHideEnabled = value
            NotificationCenter.default.post(name: SyncGramNotificationNames.flipToHideChanged, object: nil)
        case .backgroundRefresh:
            SyncGramSettings.backgroundRefreshEnabled = value
            NotificationCenter.default.post(name: SyncGramNotificationNames.backgroundRefreshChanged, object: nil)
        }
        revision.set(0)
    }, openChatListSize: {
        openChatListSizeImpl?()
    }, openShaderStyle: {
        openShaderStyleImpl?()
    }, openSecurityQuestion: {
        openSecurityQuestionImpl?()
    }, openNavigation: {
        openNavigationImpl?()
    }, openAccounts: {
        openAccountsImpl?()
    }, openCache: {
        openCacheImpl?()
    }, openSession: {
        openSessionImpl?()
    }, readAllChats: {
        // `markAllChatsAsReadInteractively` cannot fail (Signal<Never, NoError>), so only
        // the completion branch exists.
        let _ = context.engine.messages.markAllChatsAsReadInteractively(items: [(groupId: .root, filterPredicate: nil)]).startStandalone(completed: {
            DispatchQueue.main.async {
                SyncGramToast.show("Все чаты отмечены как прочитанные")
            }
        })
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        revision.get()
    )
    |> deliverOnMainQueue
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var presentationData = presentationData
        presentationData = presentationData.withUpdated(theme: presentationData.theme.withModalBlocksBackground())

        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("SyncGram"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: syncGramSettingsEntries(), style: .blocks, animateChanges: true)

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    openChatListSizeImpl = { [weak controller] in
        controller?.push(SyncGramChatListSizeController(context: context))
    }
    openShaderStyleImpl = { [weak controller] in
        controller?.push(syncGramShaderStyleController(context: context))
    }
    openSecurityQuestionImpl = { [weak controller] in
        controller?.push(SyncGramSecurityQuestionController(context: context))
    }
    openNavigationImpl = { [weak controller] in
        controller?.push(SyncGramNavigationController(context: context))
    }
    openAccountsImpl = { [weak controller] in
        controller?.push(SyncGramAccountsPanelController(context: context))
    }
    openCacheImpl = { [weak controller] in
        controller?.push(SyncGramCacheController(context: context))
    }
    openSessionImpl = { [weak controller] in
        controller?.push(SyncGramSessionController(context: context))
    }
    return controller
}