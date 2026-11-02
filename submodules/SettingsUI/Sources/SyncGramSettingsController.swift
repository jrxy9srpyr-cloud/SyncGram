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
    case copyProtection
    case screenshots
    case blockedChats
}

private final class SyncGramSettingsControllerArguments {
    let toggle: (SyncGramSettingsToggle, Bool) -> Void

    init(toggle: @escaping (SyncGramSettingsToggle, Bool) -> Void) {
        self.toggle = toggle
    }
}

private enum SyncGramSettingsSection: Int32 {
    case main
}

private enum SyncGramSettingsEntry: ItemListNodeEntry {
    case header
    case ghostMode(Bool)
    case copyProtection(Bool)
    case screenshots(Bool)
    case blockedChats(Bool)
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
        case .copyProtection:
            return 2
        case .screenshots:
            return 3
        case .blockedChats:
            return 4
        case .footer:
            return 5
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
        case .footer:
            return ItemListTextItem(presentationData: presentationData, text: .markdown("Эти настройки действуют только на этом устройстве. Удалённые сообщения остаются в локальной базе, пересылка и сохранение игнорируют клиентскую защиту, а секретные чаты не отправляют уведомления о скриншотах. Сервер по-прежнему может отклонить действие, если оно запрещено на его стороне. SyncGram никуда не отправляет твои данные."), sectionId: self.section)
        }
    }
}

private func syncGramSettingsEntries() -> [SyncGramSettingsEntry] {
    return [
        .header,
        .ghostMode(SyncGramSettings.ghostModeEnabled),
        .copyProtection(SyncGramSettings.bypassCopyProtectionEnabled),
        .screenshots(SyncGramSettings.allowSecretScreenshots),
        .blockedChats(SyncGramSettings.keepBlockedChatsEnabled),
        .footer
    ]
}

public func syncGramSettingsController(context: AccountContext) -> ViewController {
    let revision = ValuePromise<Int>(0, ignoreRepeated: false)

    let arguments = SyncGramSettingsControllerArguments(toggle: { toggle, value in
        switch toggle {
        case .ghostMode:
            SyncGramSettings.ghostModeEnabled = value
        case .copyProtection:
            SyncGramSettings.bypassCopyProtectionEnabled = value
        case .screenshots:
            SyncGramSettings.allowSecretScreenshots = value
        case .blockedChats:
            SyncGramSettings.keepBlockedChatsEnabled = value
        }
        revision.set(0)
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
    return controller
}