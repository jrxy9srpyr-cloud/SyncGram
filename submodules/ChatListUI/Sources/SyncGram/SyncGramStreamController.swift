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
}

public final class SyncGramStreamController: ViewController {
    private let context: AccountContext
    private let presentationData: PresentationData
    private let titleLabel: UILabel
    private let subtitleLabel: UILabel
    private let scrollView: UIScrollView
    private let stackView: UIStackView
    private let disposable = MetaDisposable()
    private var currentItems: [SyncGramStreamItem] = []
    private var pendingScrollOffset: CGPoint?

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.titleLabel = UILabel()
        self.subtitleLabel = UILabel()
        self.scrollView = UIScrollView()
        self.stackView = UIStackView()
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

        self.titleLabel.text = "Поток"
        self.titleLabel.font = Font.semibold(20.0)
        self.titleLabel.textColor = theme.list.itemPrimaryTextColor
        self.view.addSubview(self.titleLabel)

        self.subtitleLabel.text = "Последние сообщения из чатов всех аккаунтов в одной хронологической ленте."
        self.subtitleLabel.font = Font.regular(14.0)
        self.subtitleLabel.textColor = theme.list.itemSecondaryTextColor
        self.subtitleLabel.numberOfLines = 0
        self.view.addSubview(self.subtitleLabel)

        self.scrollView.alwaysBounceVertical = true
        self.view.addSubview(self.scrollView)
        self.stackView.axis = .vertical
        self.stackView.spacing = 8.0
        self.scrollView.addSubview(self.stackView)

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
                        result.append(SyncGramStreamItem(accountId: accountId, accountTitle: accountTitle, chatTitle: chatTitle, text: text, timestamp: message.timestamp, peerId: message.id.peerId, messageId: message.id))
                    }
                    return result
                }
            }
            return combineLatest(queue: .mainQueue(), signals)
            |> map { lists -> [SyncGramStreamItem] in
                return lists.flatMap { $0 }.sorted(by: { $0.timestamp > $1.timestamp })
            }
        }
        |> deliverOnMainQueue

        self.disposable.set(signal.start(next: { [weak self] items in
            self?.update(items)
        }))
    }

    private func update(_ items: [SyncGramStreamItem]) {
        // Keep the reader's position when the feed refreshes.
        self.pendingScrollOffset = self.scrollView.contentOffset
        for view in self.stackView.arrangedSubviews {
            view.removeFromSuperview()
        }
        let theme = self.presentationData.theme

        let selectButton = UIButton(type: .system)
        selectButton.setTitle("Выбрать чаты для Потока", for: .normal)
        selectButton.setTitleColor(theme.list.itemAccentColor, for: .normal)
        selectButton.titleLabel?.font = Font.semibold(15.0)
        selectButton.addTarget(self, action: #selector(self.selectChatsTapped), for: .touchUpInside)
        self.stackView.addArrangedSubview(selectButton)

        if !SyncGramStreamSettings.shared.hasSelection {
            let label = UILabel()
            label.text = "Чаты для Потока не выбраны."
            label.font = Font.regular(15.0)
            label.textColor = theme.list.itemSecondaryTextColor
            label.textAlignment = .center
            self.stackView.addArrangedSubview(label)
            self.view.setNeedsLayout()
            return
        }

        let filtered = items.filter { SyncGramStreamSettings.shared.isSelected(accountId: $0.accountId, peerId: $0.peerId) }
        if filtered.isEmpty {
            let label = UILabel()
            label.text = "В выбранных чатах сообщений пока нет"
            label.font = Font.regular(15.0)
            label.textColor = theme.list.itemSecondaryTextColor
            label.textAlignment = .center
            self.stackView.addArrangedSubview(label)
            self.view.setNeedsLayout()
            return
        }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        self.currentItems = Array(filtered.prefix(120))
        for (index, item) in self.currentItems.enumerated() {
            let container = UIControl()
            container.backgroundColor = theme.list.itemBlocksBackgroundColor
            container.layer.cornerRadius = 12.0
            container.tag = index
            container.addTarget(self, action: #selector(self.itemTapped(_:)), for: .touchUpInside)

            let title = UILabel()
            title.text = item.chatTitle
            title.font = Font.semibold(15.0)
            title.textColor = theme.list.itemPrimaryTextColor

            let account = UILabel()
            account.text = "\(item.accountTitle) · \(timeFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(item.timestamp))))"
            account.font = Font.regular(11.0)
            account.textColor = theme.list.itemAccentColor

            let text = UILabel()
            text.text = String(item.text.prefix(180))
            text.font = Font.regular(13.0)
            text.textColor = theme.list.itemSecondaryTextColor
            text.numberOfLines = 3

            let jump = UIButton(type: .system)
            jump.setTitle("Перейти к сообщению", for: .normal)
            jump.setTitleColor(theme.list.itemAccentColor, for: .normal)
            jump.accessibilityLabel = "Перейти к сообщению в чате"
            jump.titleLabel?.font = Font.semibold(12.0)
            jump.tag = index
            jump.addTarget(self, action: #selector(self.jumpTapped(_:)), for: .touchUpInside)

            for view in [title, account, text, jump] {
                view.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(view)
            }
            NSLayoutConstraint.activate([
                title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12.0),
                title.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12.0),
                title.topAnchor.constraint(equalTo: container.topAnchor, constant: 9.0),
                account.leadingAnchor.constraint(equalTo: title.leadingAnchor),
                account.trailingAnchor.constraint(equalTo: title.trailingAnchor),
                account.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 1.0),
                text.leadingAnchor.constraint(equalTo: title.leadingAnchor),
                text.trailingAnchor.constraint(equalTo: title.trailingAnchor),
                text.topAnchor.constraint(equalTo: account.bottomAnchor, constant: 3.0),
                jump.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12.0),
                jump.topAnchor.constraint(equalTo: text.bottomAnchor, constant: 4.0),
                jump.heightAnchor.constraint(equalToConstant: 26.0),
                jump.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6.0)
            ])
            self.stackView.addArrangedSubview(container)
        }
        self.view.setNeedsLayout()
    }

    @objc private func jumpTapped(_ sender: UIButton) {
        guard sender.tag >= 0 && sender.tag < self.currentItems.count else {
            return
        }
        let item = self.currentItems[sender.tag]
        self.context.sharedContext.navigateToChat(accountId: item.accountId, peerId: item.peerId, messageId: item.messageId)
    }

    @objc private func selectChatsTapped() {
        self.present(SyncGramStreamChatsController(context: self.context), animated: true, completion: nil)
    }

    @objc private func itemTapped(_ sender: UIControl) {
        guard sender.tag >= 0 && sender.tag < self.currentItems.count else {
            return
        }
        let item = self.currentItems[sender.tag]
        self.context.sharedContext.navigateToChat(accountId: item.accountId, peerId: item.peerId, messageId: item.messageId)
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let bounds = self.view.bounds
        let insets = self.view.safeAreaInsets
        let width = bounds.width - 40.0
        self.titleLabel.frame = CGRect(x: 20.0, y: insets.top + 16.0, width: width, height: 28.0)
        let subtitleHeight = self.subtitleLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        self.subtitleLabel.frame = CGRect(x: 20.0, y: insets.top + 50.0, width: width, height: subtitleHeight)
        let top = insets.top + 50.0 + subtitleHeight + 14.0
        self.scrollView.frame = CGRect(x: 20.0, y: top, width: width, height: bounds.height - top - insets.bottom - 16.0)
        let height = self.stackView.systemLayoutSizeFitting(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        self.stackView.frame = CGRect(x: 0.0, y: 0.0, width: width, height: height)
        self.scrollView.contentSize = CGSize(width: width, height: height)

        if let offset = self.pendingScrollOffset {
            self.pendingScrollOffset = nil
            let maxOffset = max(0.0, height - self.scrollView.bounds.height)
            self.scrollView.setContentOffset(CGPoint(x: 0.0, y: min(offset.y, maxOffset)), animated: false)
        }
    }
}