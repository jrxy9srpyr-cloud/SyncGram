import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import Postbox
import TelegramPresentationData
import SyncGramUI
import AccountContext

private struct SyncGramStreamItem {
    let accountId: AccountRecordId
    let accountTitle: String
    let chatTitle: String
    let text: String
    let timestamp: Int32
    let peerId: EnginePeer.Id
    let messageId: EngineMessage.Id
    let isOutgoing: Bool
    let isDeleted: Bool
}

private enum SyncGramStreamEntry {
    case day(String)
    case message(SyncGramStreamItem)
}

/// A single chat bubble in the aggregated "Поток" conversation.
///
/// The old implementation mixed `UIStackView` with manually positioned labels inside a
/// `UIControl`; because the bubble had no explicit height the stack could lay several rows on top
/// of each other. Everything here is measured and placed by hand in `layout(in:)`, so the height
/// that is returned is exactly the height that is used by the caller.
private final class SyncGramStreamMessageView: UIControl {
    private let bubbleView = UIView()
    private let authorLabel = UILabel()
    private let textLabel = UILabel()
    private let timeLabel = UILabel()
    private let trashView = UIImageView()

    let item: SyncGramStreamItem
    private let incoming: Bool

    init(item: SyncGramStreamItem, theme: PresentationTheme) {
        self.item = item
        self.incoming = !item.isOutgoing

        super.init(frame: .zero)

        let colors = incoming ? theme.chat.message.incoming : theme.chat.message.outgoing
        self.bubbleView.backgroundColor = colors.bubble.withoutWallpaper.fill.first ?? theme.list.itemBlocksBackgroundColor
        self.bubbleView.isUserInteractionEnabled = false
        self.bubbleView.layer.cornerRadius = 15.0
        self.bubbleView.layer.maskedCorners = incoming
            ? [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner]
            : [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner]
        self.addSubview(self.bubbleView)

        self.authorLabel.text = item.accountTitle.isEmpty ? item.chatTitle : "\(item.chatTitle) · \(item.accountTitle)"
        self.authorLabel.font = Font.semibold(12.0)
        self.authorLabel.textColor = colors.accentTextColor
        self.authorLabel.numberOfLines = 1
        self.authorLabel.lineBreakMode = .byTruncatingTail
        self.bubbleView.addSubview(self.authorLabel)

        self.textLabel.text = item.text
        self.textLabel.font = Font.regular(15.0)
        self.textLabel.textColor = colors.primaryTextColor
        self.textLabel.numberOfLines = 0
        self.textLabel.lineBreakMode = .byWordWrapping
        self.bubbleView.addSubview(self.textLabel)

        self.timeLabel.font = Font.regular(11.0)
        self.timeLabel.textColor = colors.secondaryTextColor
        self.timeLabel.textAlignment = .right
        self.bubbleView.addSubview(self.timeLabel)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        self.timeLabel.text = timeFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(item.timestamp)))

        self.trashView.image = UIImage(systemName: "trash", withConfiguration: UIImage.SymbolConfiguration(pointSize: 10.0, weight: .regular))
        self.trashView.tintColor = colors.secondaryTextColor
        self.trashView.contentMode = .scaleAspectFit
        self.trashView.isHidden = !item.isDeleted
        self.bubbleView.addSubview(self.trashView)

        if item.isDeleted {
            self.bubbleView.alpha = 0.72
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Lays the bubble out inside `width` and returns the total row height, including the vertical
    /// gap that separates it from the next message.
    func layout(in width: CGFloat) -> CGFloat {
        let sideInset: CGFloat = 12.0
        let bubbleInsets = UIEdgeInsets(top: 7.0, left: 11.0, bottom: 6.0, right: 11.0)
        let maximumBubbleWidth = max(120.0, min(width - 32.0, 460.0))
        let maximumContentWidth = maximumBubbleWidth - bubbleInsets.left - bubbleInsets.right

        let authorHeight = self.authorLabel.sizeThatFits(CGSize(width: maximumContentWidth, height: .greatestFiniteMagnitude)).height

        let trashWidth: CGFloat = self.item.isDeleted ? 14.0 : 0.0
        let timeSize = self.timeLabel.sizeThatFits(CGSize(width: maximumContentWidth, height: .greatestFiniteMagnitude))
        let measuredTextWidth = min(maximumContentWidth, ceil(self.textLabel.intrinsicContentSize.width))
        let measuredAuthorWidth = min(maximumContentWidth, ceil(self.authorLabel.intrinsicContentSize.width))
        let desiredContentWidth = max(measuredTextWidth, measuredAuthorWidth, timeSize.width + trashWidth + 4.0)
        let contentWidth = max(80.0, min(maximumContentWidth, desiredContentWidth))

        let textHeight = self.textLabel.sizeThatFits(CGSize(width: contentWidth, height: .greatestFiniteMagnitude)).height
        let footerHeight = max(timeSize.height, 12.0)

        let bubbleWidth = contentWidth + bubbleInsets.left + bubbleInsets.right
        let bubbleHeight = bubbleInsets.top + authorHeight + 3.0 + textHeight + 4.0 + footerHeight + bubbleInsets.bottom

        let bubbleX = self.incoming ? sideInset : max(sideInset, width - sideInset - bubbleWidth)
        self.bubbleView.frame = CGRect(x: bubbleX, y: 2.0, width: bubbleWidth, height: bubbleHeight)

        let contentX = bubbleInsets.left
        self.authorLabel.frame = CGRect(x: contentX, y: bubbleInsets.top, width: contentWidth, height: authorHeight)
        self.textLabel.frame = CGRect(x: contentX, y: self.authorLabel.frame.maxY + 3.0, width: contentWidth, height: textHeight)

        let footerY = self.textLabel.frame.maxY + 4.0
        let timeWidth = timeSize.width
        let timeX = contentX + contentWidth - timeWidth
        self.timeLabel.frame = CGRect(x: timeX, y: footerY + (footerHeight - timeSize.height) / 2.0, width: timeWidth, height: timeSize.height)
        if self.item.isDeleted {
            self.trashView.frame = CGRect(x: timeX - trashWidth - 3.0, y: footerY + (footerHeight - 12.0) / 2.0, width: 12.0, height: 12.0)
        }

        return bubbleHeight + 4.0
    }
}

/// A centered date separator, like the ones used between days in a real chat.
private final class SyncGramStreamDayView: UIView {
    private let label = UILabel()
    private let background = UIView()

    init(text: String, theme: PresentationTheme) {
        super.init(frame: .zero)

        self.background.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.background.layer.cornerRadius = 10.0
        self.addSubview(self.background)

        self.label.text = text
        self.label.font = Font.semibold(11.0)
        self.label.textColor = theme.list.itemSecondaryTextColor
        self.label.textAlignment = .center
        self.addSubview(self.label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func layout(in width: CGFloat) -> CGFloat {
        let measured = self.label.sizeThatFits(CGSize(width: width - 40.0, height: .greatestFiniteMagnitude))
        let backgroundWidth = measured.width + 20.0
        let backgroundHeight = max(20.0, measured.height + 6.0)
        self.background.frame = CGRect(x: (width - backgroundWidth) / 2.0, y: 8.0, width: backgroundWidth, height: backgroundHeight)
        self.label.frame = CGRect(x: self.background.frame.minX, y: self.background.frame.minY, width: backgroundWidth, height: backgroundHeight)
        return backgroundHeight + 16.0
    }
}

public final class SyncGramStreamController: ViewController {
    private let context: AccountContext
    private let presentationData: PresentationData

    private let headerView = UIView()
    private let backButton = UIButton(type: .system)
    private let avatarView = UIView()
    private let avatarLabel = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let optionsButton = UIButton(type: .system)
    private let headerSeparator = UIView()

    private let scrollView = UIScrollView()
    private let composerButton = UIButton(type: .system)
    private let emptyLabel = UILabel()

    private let disposable = MetaDisposable()
    private var entryViews: [UIView] = []
    private var currentItems: [SyncGramStreamItem] = []
    private var pendingScrollOffset: CGPoint?
    private var hasPerformedInitialScroll = false
    private var needsScrollToBottom = false

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: nil)
        self.title = "Поток"
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.disposable.dispose()
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        let theme = self.presentationData.theme
        self.view.backgroundColor = theme.list.plainBackgroundColor
        SyncGramShaderHost.install(on: self.view, backgroundColor: theme.list.plainBackgroundColor, isDark: theme.overallDarkAppearance, accent: theme.list.itemAccentColor)

        self.headerView.backgroundColor = theme.list.blocksBackgroundColor
        self.view.addSubview(self.headerView)

        self.backButton.setImage(UIImage(systemName: "chevron.left", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17.0, weight: .semibold)), for: .normal)
        self.backButton.tintColor = theme.rootController.navigationBar.buttonColor
        self.backButton.addTarget(self, action: #selector(self.backTapped), for: .touchUpInside)
        self.backButton.accessibilityLabel = "Назад"
        self.headerView.addSubview(self.backButton)

        self.avatarView.backgroundColor = theme.list.itemAccentColor
        self.avatarView.layer.cornerRadius = 19.0
        self.headerView.addSubview(self.avatarView)

        self.avatarLabel.text = "S"
        self.avatarLabel.font = Font.semibold(17.0)
        self.avatarLabel.textColor = .white
        self.avatarLabel.textAlignment = .center
        self.avatarView.addSubview(self.avatarLabel)

        self.titleLabel.text = "Поток"
        self.titleLabel.font = Font.semibold(17.0)
        self.titleLabel.textColor = theme.rootController.navigationBar.primaryTextColor
        self.headerView.addSubview(self.titleLabel)

        self.subtitleLabel.text = "Все выбранные чаты"
        self.subtitleLabel.font = Font.regular(12.0)
        self.subtitleLabel.textColor = theme.rootController.navigationBar.secondaryTextColor
        self.headerView.addSubview(self.subtitleLabel)

        self.optionsButton.setImage(UIImage(systemName: "slider.horizontal.3", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17.0, weight: .regular)), for: .normal)
        self.optionsButton.tintColor = theme.rootController.navigationBar.buttonColor
        self.optionsButton.addTarget(self, action: #selector(self.optionsTapped), for: .touchUpInside)
        self.optionsButton.accessibilityLabel = "Чаты для Потока"
        self.headerView.addSubview(self.optionsButton)

        self.headerSeparator.backgroundColor = theme.rootController.navigationBar.separatorColor
        self.headerView.addSubview(self.headerSeparator)

        self.scrollView.alwaysBounceVertical = true
        self.scrollView.backgroundColor = .clear
        self.scrollView.keyboardDismissMode = .onDrag
        self.view.addSubview(self.scrollView)

        self.composerButton.setTitle("Выбрать чаты для Потока", for: .normal)
        self.composerButton.setTitleColor(theme.list.itemAccentColor, for: .normal)
        self.composerButton.titleLabel?.font = Font.regular(15.0)
        self.composerButton.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.composerButton.layer.cornerRadius = 19.0
        self.composerButton.addTarget(self, action: #selector(self.optionsTapped), for: .touchUpInside)
        self.composerButton.accessibilityLabel = "Выбрать чаты для Потока"
        self.view.addSubview(self.composerButton)

        self.emptyLabel.text = "Чаты для Потока не выбраны."
        self.emptyLabel.font = Font.regular(15.0)
        self.emptyLabel.textColor = theme.list.itemSecondaryTextColor
        self.emptyLabel.numberOfLines = 0
        self.emptyLabel.textAlignment = .center
        self.emptyLabel.isHidden = true
        self.view.addSubview(self.emptyLabel)

        let signal = self.context.sharedContext.activeAccountContexts
        |> mapToSignal { _, accounts, _ -> Signal<[SyncGramStreamItem], NoError> in
            let signals: [Signal<[SyncGramStreamItem], NoError>] = accounts.map { accountId, accountContext, _ in
                let peerSignal = accountContext.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: accountContext.account.peerId))
                let listSignal = accountContext.account.viewTracker.tailChatListView(groupId: .root, count: 80)
                return combineLatest(queue: .mainQueue(), peerSignal, listSignal)
                |> map { peer, view -> [SyncGramStreamItem] in
                    let data = accountContext.sharedContext.currentPresentationData.with { $0 }
                    let accountTitle = peer?.displayTitle(strings: data.strings, displayOrder: data.nameDisplayOrder) ?? "Аккаунт"
                    var result: [SyncGramStreamItem] = []
                    for entry in view.0.entries {
                        guard case let .MessageEntry(entryData) = entry, let message = entryData.messages.first else { continue }
                        let chatTitle = entryData.renderedPeer.peer.flatMap(EnginePeer.init)?.displayTitle(strings: data.strings, displayOrder: data.nameDisplayOrder) ?? "Чат"
                        let text = message.text.isEmpty ? "[медиа]" : message.text
                        result.append(SyncGramStreamItem(
                            accountId: accountId,
                            accountTitle: accountTitle,
                            chatTitle: chatTitle,
                            text: text,
                            timestamp: message.timestamp,
                            peerId: message.id.peerId,
                            messageId: message.id,
                            isOutgoing: !message.flags.contains(.Incoming),
                            isDeleted: message.isSyncGramDeleted
                        ))
                    }
                    return result
                }
            }
            return combineLatest(queue: .mainQueue(), signals)
            |> map { lists -> [SyncGramStreamItem] in
                return lists.flatMap { $0 }.sorted(by: { $0.timestamp < $1.timestamp })
            }
        }
        |> deliverOnMainQueue

        self.disposable.set(signal.start(next: { [weak self] items in
            self?.update(items)
        }))
    }

    private func update(_ items: [SyncGramStreamItem]) {
        // Keep the reader's position when the feed refreshes.
        if self.hasPerformedInitialScroll {
            self.pendingScrollOffset = self.scrollView.contentOffset
        }
        for view in self.entryViews {
            view.removeFromSuperview()
        }
        self.entryViews.removeAll()

        let filtered = items.filter { SyncGramStreamSettings.shared.isSelected(accountId: $0.accountId, peerId: $0.peerId) }
        self.currentItems = Array(filtered.suffix(150))

        let theme = self.presentationData.theme
        let dayFormatter = DateFormatter()
        dayFormatter.dateStyle = .long
        dayFormatter.timeStyle = .none
        dayFormatter.doesRelativeDateFormatting = true
        var entries: [SyncGramStreamEntry] = []
        var previousDay: String?
        for item in self.currentItems {
            let day = dayFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(item.timestamp)))
            if day != previousDay {
                entries.append(.day(day))
                previousDay = day
            }
            entries.append(.message(item))
        }

        for entry in entries {
            switch entry {
            case let .day(text):
                let view = SyncGramStreamDayView(text: text, theme: theme)
                self.scrollView.addSubview(view)
                self.entryViews.append(view)
            case let .message(item):
                let view = SyncGramStreamMessageView(item: item, theme: theme)
                view.addTarget(self, action: #selector(self.messageTapped(_:)), for: .touchUpInside)
                self.scrollView.addSubview(view)
                self.entryViews.append(view)
            }
        }

        let uniquePeers = Set(self.currentItems.map { "\($0.accountId.int64):\($0.peerId.toInt64())" })
        if self.currentItems.isEmpty {
            if SyncGramStreamSettings.shared.hasSelection {
                self.subtitleLabel.text = "В выбранных чатах сообщений пока нет"
                self.emptyLabel.text = "В выбранных чатах сообщений пока нет."
            } else {
                self.subtitleLabel.text = "Чаты не выбраны"
                self.emptyLabel.text = "Выберите чаты, сообщения из которых попадут в Поток."
            }
            self.emptyLabel.isHidden = false
        } else {
            self.subtitleLabel.text = "\(uniquePeers.count) чатов · \(self.currentItems.count) сообщений"
            self.emptyLabel.isHidden = true
        }

        if !self.hasPerformedInitialScroll {
            self.needsScrollToBottom = true
        }
        self.view.setNeedsLayout()
    }

    @objc private func messageTapped(_ sender: UIControl) {
        guard let sender = sender as? SyncGramStreamMessageView else {
            return
        }
        let item = sender.item
        self.context.sharedContext.navigateToChat(accountId: item.accountId, peerId: item.peerId, messageId: item.messageId)
    }

    @objc private func optionsTapped() {
        self.present(SyncGramStreamChatsController(context: self.context), animated: true, completion: nil)
    }

    @objc private func backTapped() {
        if let navigationController = self.navigationController as? NavigationController {
            let _ = navigationController.popViewController(animated: true)
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let bounds = self.view.bounds
        let insets = self.view.safeAreaInsets

        let headerHeight = insets.top + 56.0
        self.headerView.frame = CGRect(x: 0.0, y: 0.0, width: bounds.width, height: headerHeight)

        self.backButton.frame = CGRect(x: 4.0, y: insets.top + 8.0, width: 40.0, height: 40.0)
        self.avatarView.frame = CGRect(x: 44.0, y: insets.top + 9.0, width: 38.0, height: 38.0)
        self.avatarLabel.frame = self.avatarView.bounds

        let textLeft = self.avatarView.frame.maxX + 10.0
        let textRight = bounds.width - 54.0
        self.titleLabel.frame = CGRect(x: textLeft, y: insets.top + 9.0, width: max(0.0, textRight - textLeft), height: 21.0)
        self.subtitleLabel.frame = CGRect(x: textLeft, y: insets.top + 30.0, width: max(0.0, textRight - textLeft), height: 16.0)
        self.optionsButton.frame = CGRect(x: bounds.width - 48.0, y: insets.top + 8.0, width: 40.0, height: 40.0)
        self.headerSeparator.frame = CGRect(x: 0.0, y: headerHeight - UIScreenPixel, width: bounds.width, height: UIScreenPixel)

        let composerHeight: CGFloat = 40.0
        let composerY = bounds.height - insets.bottom - composerHeight - 8.0
        self.composerButton.frame = CGRect(x: 12.0, y: composerY, width: bounds.width - 24.0, height: composerHeight)

        let scrollTop = headerHeight
        let scrollBottom = composerY - 6.0
        self.scrollView.frame = CGRect(x: 0.0, y: scrollTop, width: bounds.width, height: max(0.0, scrollBottom - scrollTop))

        self.emptyLabel.frame = CGRect(x: 32.0, y: scrollTop + 80.0, width: bounds.width - 64.0, height: 80.0)

        self.layoutEntries()
    }

    private func layoutEntries() {
        let width = self.scrollView.bounds.width
        guard width > 0.0 else {
            return
        }

        var y: CGFloat = 6.0
        for view in self.entryViews {
            let height: CGFloat
            if let view = view as? SyncGramStreamMessageView {
                height = view.layout(in: width)
            } else if let view = view as? SyncGramStreamDayView {
                height = view.layout(in: width)
            } else {
                height = 0.0
            }
            view.frame = CGRect(x: 0.0, y: y, width: width, height: height)
            y += height
        }
        y += 8.0
        self.scrollView.contentSize = CGSize(width: width, height: y)

        if let offset = self.pendingScrollOffset {
            self.pendingScrollOffset = nil
            let maxOffset = max(0.0, y - self.scrollView.bounds.height)
            self.scrollView.setContentOffset(CGPoint(x: 0.0, y: min(offset.y, maxOffset)), animated: false)
        } else if self.needsScrollToBottom && !self.currentItems.isEmpty {
            self.needsScrollToBottom = false
            self.hasPerformedInitialScroll = true
            let maxOffset = max(0.0, y - self.scrollView.bounds.height)
            self.scrollView.setContentOffset(CGPoint(x: 0.0, y: maxOffset), animated: false)
        }
    }
}