import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext

private enum SyncGramSettingsToggle: Int32 {
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
    case deletedNotifications
    case signingNotifications
}

private final class SyncGramSettingsControllerArguments {
    let toggle: (SyncGramSettingsToggle, Bool) -> Void
    let openChatListSize: () -> Void
    let openLocalPremium: () -> Void
    let openSecurityQuestion: () -> Void
    let openNavigation: () -> Void
    let openAccounts: () -> Void
    let openCache: () -> Void
    let openStream: () -> Void
    let readAllChats: () -> Void

    init(toggle: @escaping (SyncGramSettingsToggle, Bool) -> Void, openChatListSize: @escaping () -> Void, openLocalPremium: @escaping () -> Void, openSecurityQuestion: @escaping () -> Void, openNavigation: @escaping () -> Void, openAccounts: @escaping () -> Void, openCache: @escaping () -> Void, openStream: @escaping () -> Void, readAllChats: @escaping () -> Void) {
        self.toggle = toggle
        self.openChatListSize = openChatListSize
        self.openLocalPremium = openLocalPremium
        self.openSecurityQuestion = openSecurityQuestion
        self.openNavigation = openNavigation
        self.openAccounts = openAccounts
        self.openCache = openCache
        self.openStream = openStream
        self.readAllChats = readAllChats
    }
}

private enum SyncGramSettingsSection: Int32 {
    case main
}

private enum SyncGramSettingsEntry: ItemListNodeEntry {
    case header
    case ghostMode(Bool)
    case hideOnline(Bool)
    case hideReads(Bool)
    case hideTyping(Bool)
    case hideStories(Bool)
    case copyProtection(Bool)
    case screenshots(Bool)
    case blockedChats(Bool)
    case hideAds(Bool)
    case flipToHide(Bool)
    case backgroundRefresh(Bool)
    case deletedNotifications(Bool)
    case signingNotifications(Bool)
    case signingInfo(String)
    case chatListSize(String)
    case localPremium
    case securityQuestion(String)
    case navigation
    case accounts
    case cache
    case stream
    case readAll
    case footer

    var section: ItemListSectionId {
        return SyncGramSettingsSection.main.rawValue
    }

    var stableId: Int32 {
        switch self {
        case .header:
            return 0
        case .ghostMode:
            return 1
        case .hideOnline:
            return 2
        case .hideReads:
            return 3
        case .hideTyping:
            return 4
        case .hideStories:
            return 5
        case .copyProtection:
            return 6
        case .screenshots:
            return 7
        case .blockedChats:
            return 8
        case .hideAds:
            return 9
        case .flipToHide:
            return 10
        case .backgroundRefresh:
            return 11
        case .deletedNotifications:
            return 12
        case .signingNotifications:
            return 13
        case .signingInfo:
            return 14
        case .chatListSize:
            return 15
        case .localPremium:
            return 16
        case .securityQuestion:
            return 17
        case .navigation:
            return 18
        case .accounts:
            return 19
        case .cache:
            return 20
        case .stream:
            return 21
        case .readAll:
            return 22
        case .footer:
            return 23
        }
    }

    static func <(lhs: SyncGramSettingsEntry, rhs: SyncGramSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! SyncGramSettingsControllerArguments
        switch self {
        case .header:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "SyncGram", sectionId: self.section)
        case let .ghostMode(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Удалённые сообщения", text: "Сохраняет удалённые сообщения локально и помечает их.", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(.ghostMode, value)
            })
        case let .hideOnline(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Режим призрака (не показывать онлайн)", text: "Не отправляет статус «онлайн».", value: value, sectionId: self.section, style: .blocks, updated: { value in
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
        case let .screenshots(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Скриншоты в секретных чатах", text: "Не отправляет собеседнику уведомление о скриншоте.", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(.screenshots, value)
            })
        case let .blockedChats(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Сохранять чаты после блокировки", text: "Оставляет чат доступным после блокировки или бана.", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(.blockedChats, value)
            })
        case let .hideAds(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Отключение рекламы", text: "Скрывает рекламные сообщения Telegram.", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(.hideAds, value)
            })
        case let .flipToHide(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Скрывать экран при перевороте", text: "Прячет имена, аватары и сообщения, когда телефон лежит экраном вниз.", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(.flipToHide, value)
            })
        case let .backgroundRefresh(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Фоновая синхронизация", text: "Иногда проверяет обновления, когда приложение свёрнуто. iOS решает когда.", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(.backgroundRefresh, value)
            })
        case let .deletedNotifications(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Уведомления об удалённых", text: "Показывает локальный баннер, когда удалённое сообщение сохранено.", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(.deletedNotifications, value)
            })
        case let .signingNotifications(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Уведомлять об окончании подписи", text: "Локальное напоминание за день до истечения и в момент окончания срока.", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(.signingNotifications, value)
            })
        case let .signingInfo(value):
            return ItemListDisclosureItem(presentationData: presentationData, title: "Срок подписи", label: value, sectionId: self.section, style: .blocks, action: nil)
        case let .chatListSize(value):
            return ItemListDisclosureItem(presentationData: presentationData, title: "Размер списка чатов", label: value, sectionId: self.section, style: .blocks, action: {
                arguments.openChatListSize()
            })
        case .localPremium:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Локальный премиум", label: SyncGramSettings.localPremiumEnabled ? "Активно" : "Не активно", sectionId: self.section, style: .blocks, action: {
                arguments.openLocalPremium()
            })
        case let .securityQuestion(value):
            return ItemListDisclosureItem(presentationData: presentationData, title: "Контрольный вопрос", label: value, sectionId: self.section, style: .blocks, action: {
                arguments.openSecurityQuestion()
            })
        case .navigation:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Навигация", label: "Вкладки", sectionId: self.section, style: .blocks, action: {
                arguments.openNavigation()
            })
        case .accounts:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Аккаунты", label: "Панель", sectionId: self.section, style: .blocks, action: {
                arguments.openAccounts()
            })
        case .cache:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Умное управление кэшем", label: "Размер и очистка", sectionId: self.section, style: .blocks, action: {
                arguments.openCache()
            })
        case .stream:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Поток", label: "Все чаты", sectionId: self.section, style: .blocks, action: {
                arguments.openStream()
            })
        case .readAll:
            return ItemListActionItem(presentationData: presentationData, title: "Прочитать все чаты", kind: .generic, alignment: .center, sectionId: self.section, style: .blocks, action: {
                arguments.readAllChats()
            })
        case .footer:
            return ItemListTextItem(presentationData: presentationData, text: .markdown("Эти настройки действуют только на этом устройстве. Удалённые сообщения остаются в локальной базе, пересылка и сохранение игнорируют клиентскую защиту, а секретные чаты не отправляют уведомления о скриншотах. Сервер по-прежнему может отклонить действие, если оно запрещено на его стороне. SyncGram никуда не отправляет твои данные."), sectionId: self.section)
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
        .header,
        .ghostMode(SyncGramSettings.ghostModeEnabled),
        .hideOnline(SyncGramSettings.hideOnlineStatusEnabled),
        .hideReads(SyncGramSettings.hideReadReceiptsEnabled),
        .hideTyping(SyncGramSettings.hideTypingEnabled),
        .hideStories(SyncGramSettings.hideStoryViewsEnabled),
        .copyProtection(SyncGramSettings.bypassCopyProtectionEnabled),
        .screenshots(SyncGramSettings.allowSecretScreenshots),
        .blockedChats(SyncGramSettings.keepBlockedChatsEnabled),
        .hideAds(SyncGramSettings.hideAdsEnabled),
        .flipToHide(SyncGramSettings.flipToHideEnabled),
        .backgroundRefresh(SyncGramSettings.backgroundRefreshEnabled),
        .deletedNotifications(SyncGramSettings.deletedMessageNotificationsEnabled),
        .signingInfo(signingInfoText),
        .signingNotifications(SyncGramSettings.signingNotificationsEnabled),
        .chatListSize("\(Int(round(SyncGramSettings.chatListScale * 100.0)))%"),
        .localPremium,
        .securityQuestion(SyncGramChatLock.shared.hasSecurityQuestion ? "Задан" : "Не задан"),
        .navigation,
        .accounts,
        .cache,
        .stream,
        .readAll,
        .footer
    ]
}

private func syncGramActiveWindow() -> UIWindow? {
    let scenes = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
    let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
    guard let scene else {
        return nil
    }
    return scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
}

private func syncGramPresentReadAllConfirmation(success: Bool) {
    guard let window = syncGramActiveWindow() else {
        return
    }
    var controller = window.rootViewController
    while let presented = controller?.presentedViewController {
        controller = presented
    }
    let alert = UIAlertController(
        title: success ? "Готово" : "Не удалось",
        message: success ? "Все чаты отмечены как прочитанные." : "Не удалось отметить чаты как прочитанные. Проверьте подключение и попробуйте ещё раз.",
        preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
    controller?.present(alert, animated: true, completion: nil)
}

private var syncGramSettingsChangeObserver: NSObjectProtocol?

public func syncGramSettingsController(context: AccountContext) -> ViewController {
    let revision = ValuePromise<Int>(0, ignoreRepeated: false)

    if let observer = syncGramSettingsChangeObserver {
        NotificationCenter.default.removeObserver(observer)
    }
    syncGramSettingsChangeObserver = NotificationCenter.default.addObserver(forName: SyncGramNotifications.settingsChanged, object: nil, queue: .main, using: { [weak revision] _ in
        revision?.set(0)
    })

    var openChatListSizeImpl: (() -> Void)?
    var openLocalPremiumImpl: (() -> Void)?
    var openSecurityQuestionImpl: (() -> Void)?
    var openNavigationImpl: (() -> Void)?
    var openAccountsImpl: (() -> Void)?
    var openCacheImpl: (() -> Void)?
    var openStreamImpl: (() -> Void)?

    let arguments = SyncGramSettingsControllerArguments(toggle: { toggle, value in
        switch toggle {
        case .ghostMode:
            SyncGramSettings.ghostModeEnabled = value
        case .hideOnline:
            SyncGramSettings.hideOnlineStatusEnabled = value
            NotificationCenter.default.post(name: SyncGramNotifications.hideOnlineChanged, object: nil)
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
            NotificationCenter.default.post(name: SyncGramNotifications.flipToHideChanged, object: nil)
        case .backgroundRefresh:
            SyncGramSettings.backgroundRefreshEnabled = value
        case .deletedNotifications:
            SyncGramSettings.deletedMessageNotificationsEnabled = value
        case .signingNotifications:
            SyncGramSettings.signingNotificationsEnabled = value
            SyncGramSigningInfo.shared.scheduleNotificationsIfNeeded()
        }
        revision.set(0)
    }, openChatListSize: {
        openChatListSizeImpl?()
    }, openLocalPremium: {
        openLocalPremiumImpl?()
    }, openSecurityQuestion: {
        openSecurityQuestionImpl?()
    }, openNavigation: {
        openNavigationImpl?()
    }, openAccounts: {
        openAccountsImpl?()
    }, openCache: {
        openCacheImpl?()
    }, openStream: {
        openStreamImpl?()
    }, readAllChats: {
        let _ = context.engine.messages.markAllChatsAsReadInteractively(items: [(groupId: .root, filterPredicate: nil)]).startStandalone(error: { _ in
            DispatchQueue.main.async {
                syncGramPresentReadAllConfirmation(success: false)
            }
        }, completed: {
            DispatchQueue.main.async {
                syncGramPresentReadAllConfirmation(success: true)
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
    openLocalPremiumImpl = { [weak controller] in
        controller?.push(SyncGramLocalPremiumController(context: context))
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
    openStreamImpl = { [weak controller] in
        controller?.push(SyncGramStreamController(context: context))
    }
    return controller
}