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
    case copyProtection
    case screenshots
    case blockedChats
}

private final class SyncGramSettingsControllerArguments {
    let toggle: (SyncGramSettingsToggle, Bool) -> Void
    let openChatListSize: () -> Void

    init(toggle: @escaping (SyncGramSettingsToggle, Bool) -> Void, openChatListSize: @escaping () -> Void) {
        self.toggle = toggle
        self.openChatListSize = openChatListSize
    }
}

private enum SyncGramSettingsSection: Int32 {
    case main
}

private enum SyncGramSettingsEntry: ItemListNodeEntry {
    case header
    case ghostMode(Bool)
    case hideOnline(Bool)
    case copyProtection(Bool)
    case screenshots(Bool)
    case blockedChats(Bool)
    case chatListSize(String)
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
        case .copyProtection:
            return 3
        case .screenshots:
            return 4
        case .blockedChats:
            return 5
        case .chatListSize:
            return 6
        case .footer:
            return 7
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
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Удалённые сообщения", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(.ghostMode, value)
            })
        case let .hideOnline(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Режим призрака (не показывать онлайн)", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(.hideOnline, value)
            })
        case let .copyProtection(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Обход защиты от копирования", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(.copyProtection, value)
            })
        case let .screenshots(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Скриншоты в секретных чатах", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(.screenshots, value)
            })
        case let .blockedChats(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Сохранять чаты после блокировки", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(.blockedChats, value)
            })
        case let .chatListSize(value):
            return ItemListDisclosureItem(presentationData: presentationData, title: "Размер списка чатов", label: value, sectionId: self.section, style: .blocks, action: {
                arguments.openChatListSize()
            })
        case .footer:
            return ItemListTextItem(presentationData: presentationData, text: .markdown("Эти настройки действуют только на этом устройстве. Удалённые сообщения остаются в локальной базе, пересылка и сохранение игнорируют клиентскую защиту, а секретные чаты не отправляют уведомления о скриншотах. Сервер по-прежнему может отклонить действие, если оно запрещено на его стороне. SyncGram никуда не отправляет твои данные."), sectionId: self.section)
        }
    }
}

private func syncGramSettingsEntries() -> [SyncGramSettingsEntry] {
    return [
        .header,
        .ghostMode(SyncGramSettings.ghostModeEnabled),
        .hideOnline(SyncGramSettings.hideOnlineStatusEnabled),
        .copyProtection(SyncGramSettings.bypassCopyProtectionEnabled),
        .screenshots(SyncGramSettings.allowSecretScreenshots),
        .blockedChats(SyncGramSettings.keepBlockedChatsEnabled),
        .chatListSize("\(Int(round(SyncGramSettings.chatListScale * 100.0)))%"),
        .footer
    ]
}

public func syncGramSettingsController(context: AccountContext) -> ViewController {
    let revision = ValuePromise<Int>(0, ignoreRepeated: false)

    var openChatListSizeImpl: (() -> Void)?

    let arguments = SyncGramSettingsControllerArguments(toggle: { toggle, value in
        switch toggle {
        case .ghostMode:
            SyncGramSettings.ghostModeEnabled = value
        case .hideOnline:
            SyncGramSettings.hideOnlineStatusEnabled = value
        case .copyProtection:
            SyncGramSettings.bypassCopyProtectionEnabled = value
        case .screenshots:
            SyncGramSettings.allowSecretScreenshots = value
        case .blockedChats:
            SyncGramSettings.keepBlockedChatsEnabled = value
        }
        revision.set(0)
    }, openChatListSize: {
        openChatListSizeImpl?()
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
    return controller
}