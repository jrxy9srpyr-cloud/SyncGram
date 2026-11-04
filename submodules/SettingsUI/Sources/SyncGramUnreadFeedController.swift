import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import Postbox
import TelegramPresentationData
import SyncGramUI
import AccountContext

private struct SyncGramFeedItem {
    let accountId: AccountRecordId
    let accountTitle: String
    let chatTitle: String
    let unread: Int32
    let peerId: EnginePeer.Id
    let messageId: EngineMessage.Id?
}

public final class SyncGramUnreadFeedController: UIViewController {
    private let context: AccountContext
    private let presentationData: PresentationData
    private let titleLabel: UILabel
    private let scrollView: UIScrollView
    private let stackView: UIStackView
    private let disposable = MetaDisposable()

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.titleLabel = UILabel()
        self.scrollView = UIScrollView()
        self.stackView = UIStackView()
        super.init(nibName: nil, bundle: nil)
        self.title = "Все непрочитанные"
    }

    required init?(coder: NSCoder) {
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

        self.titleLabel.text = "Все непрочитанные"
        self.titleLabel.font = Font.semibold(20.0)
        self.titleLabel.textColor = theme.list.itemPrimaryTextColor
        self.view.addSubview(self.titleLabel)

        self.scrollView.alwaysBounceVertical = true
        self.view.addSubview(self.scrollView)
        self.stackView.axis = .vertical
        self.stackView.spacing = 8.0
        self.scrollView.addSubview(self.stackView)

        let signal = self.context.sharedContext.activeAccountContexts
        |> mapToSignal { _, accounts, _ -> Signal<[SyncGramFeedItem], NoError> in
            let signals: [Signal<[SyncGramFeedItem], NoError>] = accounts.map { accountId, accountContext, _ in
                let peerSignal = accountContext.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: accountContext.account.peerId))
                let listSignal = accountContext.account.viewTracker.tailChatListView(groupId: .root, count: 60)
                return combineLatest(queue: .mainQueue(), peerSignal, listSignal)
                |> map { peer, view -> [SyncGramFeedItem] in
                    let presentationData = accountContext.sharedContext.currentPresentationData.with { $0 }
                    let accountTitle = peer?.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder) ?? "Аккаунт"
                    var result: [SyncGramFeedItem] = []
                    for entry in view.0.entries {
                        guard case let .MessageEntry(data) = entry else { continue }
                        let unread = data.readState?.state.count ?? 0
                        guard unread > 0, let message = data.messages.first else { continue }
                        let chatTitle = data.renderedPeer.peer.flatMap(EnginePeer.init)?.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder) ?? "Чат"
                        result.append(SyncGramFeedItem(accountId: accountId, accountTitle: accountTitle, chatTitle: chatTitle, unread: unread, peerId: message.id.peerId, messageId: message.id))
                    }
                    return result
                }
            }
            return combineLatest(queue: .mainQueue(), signals)
            |> map { lists -> [SyncGramFeedItem] in
                return lists.flatMap { $0 }.sorted(by: { $0.unread > $1.unread })
            }
        }
        |> deliverOnMainQueue

        self.disposable.set(signal.start(next: { [weak self] items in
            self?.update(items)
        }))
    }

    private func update(_ items: [SyncGramFeedItem]) {
        for view in self.stackView.arrangedSubviews {
            view.removeFromSuperview()
        }
        let theme = self.presentationData.theme
        if items.isEmpty {
            let label = UILabel()
            label.text = "Непрочитанных нет"
            label.font = Font.regular(15.0)
            label.textColor = theme.list.itemSecondaryTextColor
            label.textAlignment = .center
            label.frame = CGRect(x: 0.0, y: 20.0, width: self.view.bounds.width - 40.0, height: 40.0)
            self.stackView.addArrangedSubview(label)
            self.view.setNeedsLayout()
            return
        }

        for item in items {
            let button = UIControl()
            button.backgroundColor = theme.list.itemBlocksBackgroundColor
            button.layer.cornerRadius = 10.0
            button.tag = Int(item.accountId.int64)
            button.accessibilityHint = "\(item.peerId.toInt64())"

            let title = UILabel()
            title.text = "\(item.chatTitle) · \(item.unread)"
            title.font = Font.semibold(15.0)
            title.textColor = theme.list.itemPrimaryTextColor

            let subtitle = UILabel()
            subtitle.text = item.accountTitle
            subtitle.font = Font.regular(12.0)
            subtitle.textColor = theme.list.itemAccentColor

            title.translatesAutoresizingMaskIntoConstraints = false
            subtitle.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(title)
            button.addSubview(subtitle)
            NSLayoutConstraint.activate([
                title.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 12.0),
                title.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -12.0),
                title.topAnchor.constraint(equalTo: button.topAnchor, constant: 9.0),
                subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
                subtitle.trailingAnchor.constraint(equalTo: title.trailingAnchor),
                subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 2.0),
                subtitle.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -9.0)
            ])

            button.addTarget(self, action: #selector(self.itemTapped(_:)), for: .touchUpInside)
            self.stackView.addArrangedSubview(button)
        }
        self.view.setNeedsLayout()
    }

    @objc private func itemTapped(_ sender: UIControl) {
        let accountId = AccountRecordId(rawValue: Int64(sender.tag))
        guard let peerValue = sender.accessibilityHint, let peerIdValue = Int64(peerValue) else {
            return
        }
        let peerId = EnginePeer.Id(peerIdValue)
        SyncGramAccountSettings.shared.markActivity(for: accountId.int64)
        self.context.sharedContext.navigateToChat(accountId: accountId, peerId: peerId, messageId: nil)
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let bounds = self.view.bounds
        let insets = self.view.safeAreaInsets
        let width = bounds.width - 40.0
        self.titleLabel.frame = CGRect(x: 20.0, y: insets.top + 16.0, width: width, height: 28.0)
        let top = insets.top + 56.0
        self.scrollView.frame = CGRect(x: 20.0, y: top, width: width, height: bounds.height - top - insets.bottom - 16.0)
        let height = self.stackView.systemLayoutSizeFitting(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        self.stackView.frame = CGRect(x: 0.0, y: 0.0, width: width, height: height)
        self.scrollView.contentSize = CGSize(width: width, height: height)
    }
}