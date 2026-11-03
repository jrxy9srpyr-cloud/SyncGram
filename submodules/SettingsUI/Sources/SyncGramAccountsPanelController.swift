import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext

private struct SyncGramAccountPanelItem {
    let recordId: AccountRecordId
    let title: String
    let username: String?
    let unreadTotal: Int32
    let unreadPrivate: Int32
    let unreadGroups: Int32
    let unreadChannels: Int32
    let isActive: Bool
}

public final class SyncGramAccountsPanelController: UIViewController {
    private let context: AccountContext
    private let presentationData: PresentationData

    private let titleLabel: UILabel
    private let subtitleLabel: UILabel
    private let scrollView: UIScrollView
    private let stackView: UIStackView
    private let addAccountButton: UIButton

    private let disposable = MetaDisposable()

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.titleLabel = UILabel()
        self.subtitleLabel = UILabel()
        self.scrollView = UIScrollView()
        self.stackView = UIStackView()
        self.addAccountButton = UIButton(type: .system)
        super.init(nibName: nil, bundle: nil)
        self.title = "Аккаунты"
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

        self.titleLabel.text = "Аккаунты"
        self.titleLabel.font = Font.semibold(20.0)
        self.titleLabel.textColor = theme.list.itemPrimaryTextColor
        self.view.addSubview(self.titleLabel)

        self.subtitleLabel.text = "Все подключённые аккаунты, их непрочитанные и быстрые действия."
        self.subtitleLabel.font = Font.regular(14.0)
        self.subtitleLabel.textColor = theme.list.itemSecondaryTextColor
        self.subtitleLabel.numberOfLines = 0
        self.view.addSubview(self.subtitleLabel)

        self.scrollView.alwaysBounceVertical = true
        self.view.addSubview(self.scrollView)
        self.stackView.axis = .vertical
        self.stackView.spacing = 10.0
        self.scrollView.addSubview(self.stackView)

        self.addAccountButton.setTitle("Добавить аккаунт", for: .normal)
        self.addAccountButton.setTitleColor(theme.list.itemAccentColor, for: .normal)
        self.addAccountButton.titleLabel?.font = Font.semibold(16.0)
        self.addAccountButton.addTarget(self, action: #selector(self.addAccountTapped), for: .touchUpInside)
        self.stackView.addArrangedSubview(self.addAccountButton)

        self.reload()
    }

    private func reload() {
        let signal = self.context.sharedContext.activeAccountContexts
        |> mapToSignal { primary, accounts, _ -> Signal<[SyncGramAccountPanelItem], NoError> in
            let signals: [Signal<SyncGramAccountPanelItem, NoError>] = accounts.map { recordId, accountContext, _ in
                let peerSignal = accountContext.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: accountContext.account.peerId))
                let countersSignal = accountContext.engine.data.get(TelegramEngine.EngineData.Item.Messages.TotalReadCounters())
                return combineLatest(queue: .mainQueue(), peerSignal, countersSignal)
                |> map { peer, counters -> SyncGramAccountPanelItem in
                    let strings = accountContext.sharedContext.currentPresentationData.with { $0 }.strings
                    let name = peer?.displayTitle(strings: strings, displayOrder: accountContext.sharedContext.currentPresentationData.with { $0 }.nameDisplayOrder) ?? "Аккаунт"
                    let username = peer?.addressName
                    let privateCount = counters.count(for: .raw, in: .messages, with: [.contact, .nonContact])
                    let groups = counters.count(for: .raw, in: .messages, with: .group)
                    let channels = counters.count(for: .raw, in: .messages, with: .channel)
                    return SyncGramAccountPanelItem(
                        recordId: recordId,
                        title: name,
                        username: username,
                        unreadTotal: privateCount + groups + channels,
                        unreadPrivate: privateCount,
                        unreadGroups: groups,
                        unreadChannels: channels,
                        isActive: primary?.account.id == accountContext.account.id
                    )
                }
            }
            return combineLatest(queue: .mainQueue(), signals)
        }
        |> deliverOnMainQueue

        self.disposable.set(signal.start(next: { [weak self] items in
            self?.updateItems(items)
        }))
    }

    private func updateItems(_ items: [SyncGramAccountPanelItem]) {
        for view in self.stackView.arrangedSubviews {
            if view !== self.addAccountButton {
                view.removeFromSuperview()
            }
        }

        let theme = self.presentationData.theme
        var insertionIndex = 0
        for item in items {
            let container = UIControl()
            container.backgroundColor = theme.list.itemBlocksBackgroundColor
            container.layer.cornerRadius = 12.0
            container.addTarget(self, action: #selector(self.accountTapped(_:)), for: .touchUpInside)
            container.tag = Int(item.recordId.int64)

            let title = UILabel()
            title.text = item.title
            title.font = Font.semibold(17.0)
            title.textColor = theme.list.itemPrimaryTextColor

            let username = UILabel()
            username.text = "@\(item.username ?? "—") · \(item.unreadTotal) непрочитанных"
            username.font = Font.regular(14.0)
            username.textColor = theme.list.itemSecondaryTextColor

            let categories = UILabel()
            categories.text = "\(item.unreadPrivate) личных · \(item.unreadGroups) групп · \(item.unreadChannels) каналов"
            categories.font = Font.regular(13.0)
            categories.textColor = theme.list.itemSecondaryTextColor

            let status = UILabel()
            status.text = item.isActive ? "Активен" : "Не активен"
            status.font = Font.semibold(13.0)
            status.textColor = item.isActive ? theme.list.itemAccentColor : theme.list.itemSecondaryTextColor

            let actions = UIStackView()
            actions.axis = .horizontal
            actions.spacing = 8.0

            if item.unreadTotal > 0 {
                let open = UIButton(type: .system)
                open.setTitle("Открыть непрочитанные", for: .normal)
                open.titleLabel?.font = Font.semibold(13.0)
                open.tag = Int(item.recordId.int64)
                open.addTarget(self, action: #selector(self.openUnreadTapped(_:)), for: .touchUpInside)
                actions.addArrangedSubview(open)
            }

            if let usernameValue = item.username {
                let copy = UIButton(type: .system)
                copy.setTitle("Скопировать username", for: .normal)
                copy.titleLabel?.font = Font.regular(13.0)
                copy.tag = Int(item.recordId.int64)
                copy.accessibilityHint = usernameValue
                copy.addTarget(self, action: #selector(self.copyUsernameTapped(_:)), for: .touchUpInside)
                actions.addArrangedSubview(copy)
            }

            for view in [title, username, categories, status, actions] {
                view.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(view)
            }

            NSLayoutConstraint.activate([
                title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14.0),
                title.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14.0),
                title.topAnchor.constraint(equalTo: container.topAnchor, constant: 12.0),
                username.leadingAnchor.constraint(equalTo: title.leadingAnchor),
                username.trailingAnchor.constraint(equalTo: title.trailingAnchor),
                username.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 2.0),
                categories.leadingAnchor.constraint(equalTo: title.leadingAnchor),
                categories.trailingAnchor.constraint(equalTo: title.trailingAnchor),
                categories.topAnchor.constraint(equalTo: username.bottomAnchor, constant: 2.0),
                status.leadingAnchor.constraint(equalTo: title.leadingAnchor),
                status.topAnchor.constraint(equalTo: categories.bottomAnchor, constant: 4.0),
                actions.leadingAnchor.constraint(equalTo: title.leadingAnchor),
                actions.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -14.0),
                actions.topAnchor.constraint(equalTo: status.bottomAnchor, constant: 8.0),
                actions.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12.0)
            ])

            self.stackView.insertArrangedSubview(container, at: insertionIndex)
            insertionIndex += 1
        }
    }

    @objc private func accountTapped(_ sender: UIControl) {
        let id = AccountRecordId(rawValue: Int64(sender.tag))
        self.context.sharedContext.switchToAccount(id: id)
    }

    @objc private func openUnreadTapped(_ sender: UIButton) {
        let id = AccountRecordId(rawValue: Int64(sender.tag))
        self.context.sharedContext.switchToAccount(id: id)
        self.context.sharedContext.openChatsController(activateSearch: false, filter: .chats, query: nil)
    }

    @objc private func copyUsernameTapped(_ sender: UIButton) {
        if let hint = sender.accessibilityHint {
            UIPasteboard.general.string = hint
        }
    }

    @objc private func addAccountTapped() {
        self.context.sharedContext.beginNewAuth(testingEnvironment: self.context.account.testingEnvironment)
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let bounds = self.view.bounds
        let insets = self.view.safeAreaInsets
        let width = bounds.width - 40.0
        let top = insets.top + 16.0

        self.titleLabel.frame = CGRect(x: 20.0, y: top, width: width, height: 28.0)
        self.subtitleLabel.frame = CGRect(x: 20.0, y: top + 34.0, width: width, height: 40.0)

        let scrollTop = top + 88.0
        self.scrollView.frame = CGRect(x: 20.0, y: scrollTop, width: width, height: bounds.height - scrollTop - insets.bottom - 16.0)
        let height = self.stackView.systemLayoutSizeFitting(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        self.stackView.frame = CGRect(x: 0.0, y: 0.0, width: width, height: height)
        self.scrollView.contentSize = CGSize(width: width, height: height)
    }
}