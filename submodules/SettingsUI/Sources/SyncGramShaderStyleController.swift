import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext

private enum SyncGramShaderStyleSection: Int32 {
    case styles
}

private final class SyncGramShaderStyleControllerArguments {
    let select: (SyncGramShaderStyle) -> Void

    init(select: @escaping (SyncGramShaderStyle) -> Void) {
        self.select = select
    }
}

private enum SyncGramShaderStyleEntry: ItemListNodeEntry {
    case header
    case style(SyncGramShaderStyle, Bool)
    case footer

    var section: ItemListSectionId {
        return SyncGramShaderStyleSection.styles.rawValue
    }

    var stableId: Int32 {
        switch self {
        case .header:
            return 0
        case let .style(style, _):
            return 1 + style.rawValue
        case .footer:
            return 100
        }
    }

    static func <(lhs: SyncGramShaderStyleEntry, rhs: SyncGramShaderStyleEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! SyncGramShaderStyleControllerArguments
        switch self {
        case .header:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "Стиль фона", sectionId: self.section)
        case let .style(style, checked):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .legacy, icon: syncGramShaderStyleSwatch(style), iconSize: CGSize(width: 28.0, height: 28.0), title: style.title, subtitle: style.subtitle, style: .left, checked: checked, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.select(style)
            })
        case .footer:
            return ItemListTextItem(presentationData: presentationData, text: .markdown("Фон живёт на этом устройстве и не отправляется в Telegram. Анимация работает с частотой 30 кадров в секунду и останавливается, когда экран не виден. Если включён режим уменьшения движения в iOS, узор движется медленнее."), sectionId: self.section)
        }
    }
}

private func syncGramShaderStyleSwatchColors(_ style: SyncGramShaderStyle) -> [UIColor] {
    switch style {
    case .aurora:
        return [UIColor(red: 0.13, green: 0.11, blue: 0.14, alpha: 1.0), UIColor(red: 0.70, green: 0.45, blue: 0.27, alpha: 1.0)]
    case .waves:
        return [UIColor(red: 0.09, green: 0.16, blue: 0.18, alpha: 1.0), UIColor(red: 0.36, green: 0.57, blue: 0.54, alpha: 1.0)]
    case .pattern:
        return [UIColor(red: 0.20, green: 0.16, blue: 0.13, alpha: 1.0), UIColor(red: 0.80, green: 0.61, blue: 0.45, alpha: 1.0)]
    case .bubbles:
        return [UIColor(red: 0.16, green: 0.20, blue: 0.21, alpha: 1.0), UIColor(red: 0.74, green: 0.80, blue: 0.76, alpha: 1.0)]
    case .dunes:
        return [UIColor(red: 0.24, green: 0.16, blue: 0.11, alpha: 1.0), UIColor(red: 0.87, green: 0.68, blue: 0.47, alpha: 1.0)]
    }
}

private func syncGramShaderStyleSwatch(_ style: SyncGramShaderStyle) -> UIImage {
    let size = CGSize(width: 28.0, height: 28.0)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
        let rect = CGRect(origin: CGPoint(), size: size)
        let path = UIBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 8.0)
        path.addClip()
        let colors = syncGramShaderStyleSwatchColors(style).map { $0.cgColor } as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0]) {
            context.cgContext.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: size.width, y: size.height), options: [])
        }
    }
}

private func syncGramShaderStyleEntries() -> [SyncGramShaderStyleEntry] {
    var entries: [SyncGramShaderStyleEntry] = [.header]
    for style in SyncGramShaderStyle.allCases {
        entries.append(.style(style, SyncGramSettings.shaderStyle == style))
    }
    entries.append(.footer)
    return entries
}

private var syncGramShaderStyleChangeObserver: NSObjectProtocol?

public func syncGramShaderStyleController(context: AccountContext) -> ViewController {
    let revision = ValuePromise<Int>(0, ignoreRepeated: false)

    if let observer = syncGramShaderStyleChangeObserver {
        NotificationCenter.default.removeObserver(observer)
    }
    syncGramShaderStyleChangeObserver = NotificationCenter.default.addObserver(forName: SyncGramNotificationNames.shaderChanged, object: nil, queue: .main, using: { [weak revision] _ in
        revision?.set(0)
    })

    let arguments = SyncGramShaderStyleControllerArguments(select: { style in
        SyncGramSettings.shaderStyle = style
        NotificationCenter.default.post(name: SyncGramNotificationNames.shaderChanged, object: nil)
        NotificationCenter.default.post(name: SyncGramNotificationNames.settingsChanged, object: nil)
        revision.set(0)
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        revision.get()
    )
    |> deliverOnMainQueue
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Стиль фона"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: syncGramShaderStyleEntries(), style: .blocks, animateChanges: true)

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    return controller
}