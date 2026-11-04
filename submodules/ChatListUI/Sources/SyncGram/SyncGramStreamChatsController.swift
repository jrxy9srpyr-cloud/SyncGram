import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import Postbox
import TelegramPresentationData
import SyncGramUI
import AccountContext
import AvatarNode

private struct SyncGramStreamChatItem {
    let accountId: AccountRecordId
    let accountContext: AccountContext
    let accountTitle: String
    let peerId: EnginePeer.Id
    let chatTitle: String
    let avatarPeer: EnginePeer?
}

/// A single chat row in the "Чаты для Потока" picker. Everything is measured and placed by hand in
/// `layout(in:)`, so the row can never overlap the buttons above it or the next row.
private final class SyncGramStreamChatRowView: UIControl {
    let item: SyncGramStreamChatItem

    private let avatarNode: AvatarNode
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let checkLabel = UILabel()

    init(item: SyncGramStreamChatItem, theme: PresentationTheme) {
        self.item = item
        self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 14.0))

        super.init(frame: .zero)

        self.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.layer.cornerRadius = 11.0
        self.clipsToBounds = true

        self.addSubview(self.avatarNode.view)
        self.avatarNode.updateSize(size: CGSize(width: 38.0, height: 38.0))
        if let peer = item.avatarPeer {
            self.avatarNode.setPeer(context: item.accountContext, theme: theme, peer: peer, synchronousLoad: true, displayDimensions: CGSize(width: 38.0, height: 38.0))
        }

        self.titleLabel.font = Font.semibold(15.0)
        self.titleLabel.textColor = theme.list.itemPrimaryTextColor
        self.titleLabel.text = item.chatTitle
        self.titleLabel.numberOfLines = 1
        self.titleLabel.lineBreakMode = .byTruncatingTail
        self.addSubview(self.titleLabel)

        self.subtitleLabel.font = Font.regular(12.0)
        self.subtitleLabel.textColor = theme.list.itemSecondaryTextColor
        self.subtitleLabel.text = item.accountTitle
        self.subtitleLabel.numberOfLines = 1
        self.subtitleLabel.lineBreakMode = .byTruncatingTail
        self.addSubview(self.subtitleLabel)

        self.checkLabel.font = Font.semibold(18.0)
        self.checkLabel.textColor = theme.list.itemAccentColor
        self.checkLabel.textAlignment = .center
        self.addSubview(self.checkLabel)

        self.setSelected(SyncGramStreamSettings.shared.isSelected(accountId: item.accountId, peerId: item.peerId))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSelected(_ selected: Bool) {
        self.checkLabel.text = selected ? "✓" : ""
    }

    func layout(in width: CGFloat) -> CGFloat {
        self.avatarNode.frame = CGRect(x: 10.0, y: 8.0, width: 38.0, height: 38.0)
        let textLeft = 60.0
        let textWidth = max(0.0, width - textLeft - 46.0)
        self.titleLabel.frame = CGRect(x: textLeft, y: 8.0, width: textWidth, height: 20.0)
        self.subtitleLabel.frame = CGRect(x: textLeft, y: 29.0, width: textWidth, height: 16.0)
        self.checkLabel.frame = CGRect(x: width - 42.0, y: 17.0, width: 30.0, height: 20.0)
        return 54.0
    }
}

public final class SyncGramStreamChatsController: ViewController {
    private let context: AccountContext
    private let presentationData: PresentationData

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let selectAllButton = UIButton(type: .system)
    private let clearButton = UIButton(type: .system)
    private let scrollView = UIScrollView()
    private let emptyLabel = UILabel()

    private let disposable = MetaDisposable()
    private let revision = ValuePromise<Int>(0, ignoreRepeated: false)
    private var revisionValue = 0
    private var selectionObserver: NSObjectProtocol?
    private var items: [SyncGramStreamChatItem] = []
    private var rowViews: [SyncGramStreamChatRowView] = []
    private var pendingScrollOffset: CGPoint?

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: nil)
        self.title = "Чаты для Потока"
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.disposable.dispose()
        if let observer = self.selectionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        let theme = self.presentationData.theme
        self.view.backgroundColor = theme.list.plainBackgroundColor
        SyncGramShaderHost.install(on: self.view, backgroundColor: theme.list.plainBackgroundColor, isDark: theme.overallDarkAppearance, accent: theme.list.itemAccentColor)

        self.titleLabel.text = "Чаты для Потока"
        self.titleLabel.font = Font.semibold(20.0)
        self.titleLabel.textColor = theme.list.itemPrimaryTextColor
        self.view.addSubview(self.titleLabel)

        self.subtitleLabel.text = "Отметь чаты, сообщения из которых должны попадать в общую ленту."
        self.subtitleLabel.font = Font.regular(14.0)
        self.subtitleLabel.textColor = theme.list.itemSecondaryTextColor
        self.subtitleLabel.numberOfLines = 0
        self.view.addSubview(self.subtitleLabel)

        self.selectAllButton.setTitle("Выбрать все", for: .normal)
        self.selectAllButton.setTitleColor(theme.list.itemAccentColor, for: .normal)
        self.selectAllButton.titleLabel?.font = Font.semibold(14.0)
        self.selectAllButton.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.selectAllButton.layer.cornerRadius = 10.0
        self.selectAllButton.addTarget(self, action: #selector(self.selectAllTapped), for: .touchUpInside)
        self.view.addSubview(self.selectAllButton)

        self.clearButton.setTitle("Снять все", for: .normal)
        self.clearButton.setTitleColor(theme.list.itemDestructiveColor, for: .normal)
        self.clearButton.titleLabel?.font = Font.semibold(14.0)
        self.clearButton.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.clearButton.layer.cornerRadius = 10.0
        self.clearButton.addTarget(self, action: #selector(self.clearTapped), for: .touchUpInside)
        self.view.addSubview(self.clearButton)

        self.scrollView.alwaysBounceVertical = true
        self.scrollView.backgroundColor = .clear
        self.view.addSubview(self.scrollView)

        self.emptyLabel.text = "Загрузка чатов…"
        self.emptyLabel.font = Font.regular(15.0)
        self.emptyLabel.textColor = theme.list.itemSecondaryTextColor
        self.emptyLabel.numberOfLines = 0
        self.emptyLabel.textAlignment = .center
        self.emptyLabel.isHidden = true
        self.view.addSubview(self.emptyLabel)

        self.selectionObserver = NotificationCenter.default.addObserver(forName: SyncGramNotificationNames.streamSelectionChanged, object: nil, queue: .main, using: { [weak self] _ in
            self?.syncRowsSelection()
        })

        let signal = combineLatest(queue: .mainQueue(),
            self.context.sharedContext.activeAccountContexts,
            self.revision.get()
        )
        |> mapToSignal { activeAccounts, _ -> Signal<[SyncGramStreamChatItem], NoError> in
            let accounts = activeAccounts.1
            let signals: [Signal<[SyncGramStreamChatItem], NoError>] = accounts.map { accountId, accountContext, _ in
                let peerSignal = accountContext.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: accountContext.account.peerId))
                let listSignal = accountContext.account.viewTracker.tailChatListView(groupId: .root, count: 200)
                return combineLatest(queue: .mainQueue(), peerSignal, listSignal)
                |> map { peer, view -> [SyncGramStreamChatItem] in
                    let presentationData = accountContext.sharedContext.currentPresentationData.with { $0 }
                    let accountTitle = peer?.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder) ?? "Аккаунт"
                    var result: [SyncGramStreamChatItem] = []
                    for entry in view.0.entries {
                        guard case let .MessageEntry(data) = entry else { continue }
                        let avatarPeer = data.renderedPeer.peer.flatMap(EnginePeer.init)
                        let chatTitle = avatarPeer?.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder) ?? "Чат"
                        result.append(SyncGramStreamChatItem(
                            accountId: accountId,
                            accountContext: accountContext,
                            accountTitle: accountTitle,
                            peerId: data.renderedPeer.peerId,
                            chatTitle: chatTitle,
                            avatarPeer: avatarPeer
                        ))
                    }
                    return result
                }
            }
            return combineLatest(queue: .mainQueue(), signals)
            |> map { lists -> [SyncGramStreamChatItem] in
                var result: [SyncGramStreamChatItem] = []
                var seen = Set<String>()
                for item in lists.flatMap({ $0 }) {
                    let key = "\(item.accountId.int64):\(item.peerId.toInt64())"
                    if !seen.insert(key).inserted {
                        continue
                    }
                    result.append(item)
                }
                return result.sorted(by: { $0.chatTitle.lowercased() < $1.chatTitle.lowercased() })
            }
        }
        |> deliverOnMainQueue

        self.disposable.set(signal.start(next: { [weak self] items in
            self?.update(items)
        }))
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // The account list and the chat list view load asynchronously. Re-subscribing every time
        // the picker appears means the chats show up on the first open instead of requiring the
        // user to open the stream several times.
        self.revisionValue += 1
        self.revision.set(self.revisionValue)
    }

    private func update(_ items: [SyncGramStreamChatItem]) {
        self.pendingScrollOffset = self.scrollView.contentOffset
        self.items = items

        for row in self.rowViews {
            row.removeFromSuperview()
        }
        self.rowViews.removeAll()

        let theme = self.presentationData.theme
        for (index, item) in items.enumerated() {
            let row = SyncGramStreamChatRowView(item: item, theme: theme)
            row.tag = index
            row.addTarget(self, action: #selector(self.rowTapped(_:)), for: .touchUpInside)
            self.scrollView.addSubview(row)
            self.rowViews.append(row)
        }

        if items.isEmpty {
            self.emptyLabel.text = "Нет доступных чатов. Подождите немного — список загрузится."
            self.emptyLabel.isHidden = false
        } else {
            self.emptyLabel.isHidden = true
        }
        self.view.setNeedsLayout()
    }

    private func syncRowsSelection() {
        for row in self.rowViews {
            row.setSelected(SyncGramStreamSettings.shared.isSelected(accountId: row.item.accountId, peerId: row.item.peerId))
        }
    }

    @objc private func rowTapped(_ sender: UIControl) {
        let index = sender.tag
        guard index >= 0 && index < self.items.count else {
            return
        }
        let item = self.items[index]
        let selected = SyncGramStreamSettings.shared.isSelected(accountId: item.accountId, peerId: item.peerId)
        SyncGramStreamSettings.shared.setSelected(!selected, accountId: item.accountId, peerId: item.peerId)
        if index < self.rowViews.count {
            self.rowViews[index].setSelected(!selected)
        }
    }

    @objc private func selectAllTapped() {
        for item in self.items {
            SyncGramStreamSettings.shared.setSelected(true, accountId: item.accountId, peerId: item.peerId, notify: false)
        }
        SyncGramStreamSettings.shared.notifySelectionChanged()
        self.syncRowsSelection()
    }

    @objc private func clearTapped() {
        SyncGramStreamSettings.shared.clear()
        self.syncRowsSelection()
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let bounds = self.view.bounds
        let insets = self.view.safeAreaInsets
        let width = bounds.width - 40.0

        var y = insets.top + 16.0
        self.titleLabel.frame = CGRect(x: 20.0, y: y, width: width, height: 26.0)
        y += 30.0

        let subtitleHeight = self.subtitleLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        self.subtitleLabel.frame = CGRect(x: 20.0, y: y, width: width, height: subtitleHeight)
        y += subtitleHeight + 12.0

        let actionGap: CGFloat = 8.0
        let actionWidth = floor((width - actionGap) / 2.0)
        self.selectAllButton.frame = CGRect(x: 20.0, y: y, width: actionWidth, height: 34.0)
        self.clearButton.frame = CGRect(x: 20.0 + actionWidth + actionGap, y: y, width: actionWidth, height: 34.0)
        y += 34.0 + 10.0

        let scrollTop = y
        self.scrollView.frame = CGRect(x: 20.0, y: scrollTop, width: width, height: max(0.0, bounds.height - scrollTop - insets.bottom - 16.0))
        self.emptyLabel.frame = CGRect(x: 32.0, y: scrollTop + 40.0, width: bounds.width - 64.0, height: 60.0)

        self.layoutRows()
    }

    private func layoutRows() {
        let width = self.scrollView.bounds.width
        guard width > 0.0 else {
            return
        }

        var y: CGFloat = 0.0
        for row in self.rowViews {
            let height = row.layout(in: width)
            row.frame = CGRect(x: 0.0, y: y, width: width, height: height)
            y += height + 6.0
        }
        self.scrollView.contentSize = CGSize(width: width, height: max(0.0, y - 6.0))

        if let offset = self.pendingScrollOffset {
            self.pendingScrollOffset = nil
            let maxOffset = max(0.0, self.scrollView.contentSize.height - self.scrollView.bounds.height)
            self.scrollView.setContentOffset(CGPoint(x: 0.0, y: min(offset.y, maxOffset)), animated: false)
        }
    }
}