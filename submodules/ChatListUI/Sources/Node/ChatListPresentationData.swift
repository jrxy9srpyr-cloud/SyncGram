import Foundation
import UIKit
import TelegramPresentationData
import TelegramUIPreferences
import TelegramCore

public final class ChatListPresentationData {
    public let theme: PresentationTheme
    public let fontSize: PresentationFontSize
    public let strings: PresentationStrings
    public let dateTimeFormat: PresentationDateTimeFormat
    public let nameSortOrder: PresentationPersonNameOrder
    public let nameDisplayOrder: PresentationPersonNameOrder
    public let disableAnimations: Bool
    
    /// Scale of the user's "chat list size" preference captured when this instance was made.
    /// Storing it avoids reading UserDefaults on every label/avatar measurement.
    public let syncGramScale: CGFloat

    /// Chat list base font size after the user's "chat list size" preference is applied.
    /// The chat list rows are laid out with this value, so reducing it shrinks avatars,
    /// fonts and row heights while the row keeps the full width of the list.
    public var syncGramScaledBaseFontSize: CGFloat {
        return max(9.0, floor(self.fontSize.baseDisplaySize * self.syncGramScale))
    }

    public init(theme: PresentationTheme, fontSize: PresentationFontSize, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder, disableAnimations: Bool, syncGramScale: Double = SyncGramChatListMetrics.scale) {
        self.theme = theme
        self.fontSize = fontSize
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.nameSortOrder = nameSortOrder
        self.nameDisplayOrder = nameDisplayOrder
        self.disableAnimations = disableAnimations
        self.syncGramScale = CGFloat(syncGramScale)
    }
}
