import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramUIPreferences
import TelegramPresentationData

public protocol ItemListItemTag {
    func isEqual(to other: ItemListItemTag) -> Bool
}

public protocol ItemListItem {
    var sectionId: ItemListSectionId { get }
    var tag: ItemListItemTag? { get }
    var isAlwaysPlain: Bool { get }
    var requestsNoInset: Bool { get }
}

public protocol ItemListRevealOptionsStatefulItem: ItemListItem {
    var hasActiveRevealOptions: Bool { get }
}

public extension ItemListItem {
    //let accessoryItem: ListViewAccessoryItem?
    
    var isAlwaysPlain: Bool {
        return false
    }
    
    var tag: ItemListItemTag? {
        return nil
    }
    
    var requestsNoInset: Bool {
        return false
    }
}

public protocol ItemListItemNode {
    var tag: ItemListItemTag? { get }
    
    func displayHighlight()
}

public extension ItemListItemNode {
    func displayHighlight() {
    }
}

public protocol ItemListItemFocusableNode {
    func focus()
    func selectAll()
}

public enum ItemListInsetWithOtherSection {
    case none
    case full
    case reduced
}

public enum ItemListNeighbor {
    case none
    case otherSection(ItemListInsetWithOtherSection)
    case sameSection(alwaysPlain: Bool)
}

public struct ItemListNeighbors {
    public var top: ItemListNeighbor
    public var bottom: ItemListNeighbor
    public var topHasActiveRevealOptions: Bool
    public var bottomHasActiveRevealOptions: Bool
    
    public init(top: ItemListNeighbor, bottom: ItemListNeighbor, topHasActiveRevealOptions: Bool = false, bottomHasActiveRevealOptions: Bool = false) {
        self.top = top
        self.bottom = bottom
        self.topHasActiveRevealOptions = topHasActiveRevealOptions
        self.bottomHasActiveRevealOptions = bottomHasActiveRevealOptions
    }
}

public func itemListNeighborsPlainInsets(_ neighbors: ItemListNeighbors) -> UIEdgeInsets {
    var insets = UIEdgeInsets()
    switch neighbors.top {
    case .otherSection:
        insets.top += 22.0
    case .none, .sameSection:
        break
    }
    switch neighbors.bottom {
    case .none:
        insets.bottom += 22.0
    case .otherSection, .sameSection:
        break
    }
    return insets
}

public func itemListNeighborsGroupedInsets(_ neighbors: ItemListNeighbors, _ params: ListViewItemLayoutParams) -> UIEdgeInsets {
    if params.isStandalone {
        return UIEdgeInsets()
    }
    
    let topInset: CGFloat
    switch neighbors.top {
    case .none:
        if itemListHasRoundedBlockLayout(params) {
            topInset = UIScreenPixel + 24.0
        } else {
            topInset = UIScreenPixel + 35.0
        }
    case .sameSection:
        topInset = 0.0
    case let .otherSection(otherInset):
        switch otherInset {
        case .none:
            topInset = 0.0
        case .full:
            topInset = UIScreenPixel + 35.0
        case .reduced:
            topInset = UIScreenPixel + 16.0
        }
    }
    let bottomInset: CGFloat
    switch neighbors.bottom {
    case .sameSection, .otherSection:
        bottomInset = 0.0
    case .none:
        bottomInset = UIScreenPixel + 35.0
    }
    return UIEdgeInsets(top: topInset, left: 0.0, bottom: bottomInset, right: 0.0)
}

public func itemListHasRoundedBlockLayout(_ params: ListViewItemLayoutParams) -> Bool {
    return params.width >= 320.0
}

/// Shared handling for the animated background.
///
/// A `.blocks` row paints its background across the full width of the list, and a per-row
/// `maskNode` image normally paints the page background over the square corners. With the shader
/// behind the list that overlay is an opaque theme color, which shows up as black square corners
/// around every rounded tile. When the shader is enabled the row background is instead inset to the
/// content column and rounded, and the overlay is dropped. Returns `nil` when nothing needs to be
/// changed, so callers on the normal (non-shader) path keep their existing frames and animations.
public func itemListSyncGramBlockBackground(backgroundNode: ASDisplayNode, maskNode: ASImageNode, frame: CGRect, params: ListViewItemLayoutParams, hasTopCorners: Bool, hasBottomCorners: Bool, glass: Bool) -> CGRect? {
    guard SyncGramSettings.shaderEnabled else {
        if backgroundNode.layer.masksToBounds {
            backgroundNode.layer.masksToBounds = false
            backgroundNode.layer.cornerRadius = 0.0
            backgroundNode.layer.maskedCorners = []
        }
        return nil
    }

    maskNode.image = nil

    var maskedCorners: CACornerMask = []
    if hasTopCorners {
        maskedCorners.insert(.layerMinXMinYCorner)
        maskedCorners.insert(.layerMaxXMinYCorner)
    }
    if hasBottomCorners {
        maskedCorners.insert(.layerMinXMaxYCorner)
        maskedCorners.insert(.layerMaxXMaxYCorner)
    }
    backgroundNode.layer.cornerRadius = glass ? 26.0 : 11.0
    backgroundNode.layer.maskedCorners = maskedCorners
    backgroundNode.layer.masksToBounds = !maskedCorners.isEmpty

    return CGRect(
        x: params.leftInset,
        y: frame.minY,
        width: max(0.0, params.width - params.leftInset - params.rightInset),
        height: frame.height
    )
}

public final class ItemListPresentationData: Equatable {
    public let theme: PresentationTheme
    public let fontSize: PresentationFontSize
    public let strings: PresentationStrings
    public let nameDisplayOrder: PresentationPersonNameOrder
    public let dateTimeFormat: PresentationDateTimeFormat
    
    public init(theme: PresentationTheme, fontSize: PresentationFontSize, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, dateTimeFormat: PresentationDateTimeFormat) {
        self.theme = theme
        self.fontSize = fontSize
        self.strings = strings
        self.nameDisplayOrder = nameDisplayOrder
        self.dateTimeFormat = dateTimeFormat
    }
    
    public static func ==(lhs: ItemListPresentationData, rhs: ItemListPresentationData) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.fontSize != rhs.fontSize {
            return false
        }
        if lhs.nameDisplayOrder != rhs.nameDisplayOrder {
            return false
        }
        if lhs.dateTimeFormat != rhs.dateTimeFormat {
            return false
        }
        return true
    }
}

public extension PresentationFontSize {
    var itemListBaseHeaderFontSize: CGFloat {
        return floor(self.itemListBaseFontSize * 13.0 / 17.0)
    }
    
    var itemListBaseFontSize: CGFloat {
        switch self {
        case .extraSmall:
            return 14.0
        case .small:
            return 15.0
        case .medium:
            return 16.0
        case .regular:
            return 17.0
        case .large:
            return 19.0
        case .extraLarge:
            return 23.0
        case .extraLargeX2:
            return 26.0
        }
    }
    
    var itemListBaseLabelFontSize: CGFloat {
        switch self {
        case .extraSmall:
            return 11.0
        case .small:
            return 12.0
        case .medium:
            return 13.0
        case .regular:
            return 14.0
        case .large:
            return 16.0
        case .extraLarge:
            return 20.0
        case .extraLargeX2:
            return 23.0
        }
    }
}

public extension ItemListPresentationData {
    convenience init(_ presentationData: PresentationData) {
        self.init(theme: presentationData.theme, fontSize: presentationData.listsFontSize, strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder, dateTimeFormat: presentationData.dateTimeFormat)
    }
}
