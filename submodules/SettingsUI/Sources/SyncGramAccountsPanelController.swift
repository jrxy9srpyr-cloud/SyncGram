import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import Postbox
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
    let lastChatTitle: String?
    let lastMessageText: String?
    let notificationsEnabled: Bool
    let mutedUntil: Date?
    let lastActivity: Date?
    let connectionStatus: String
    let latestPeerId: EnginePeer.Id?
    let latestMessageId: EngineMessage.Id?
}

public final class SyncGramAccountsPanelController: ViewController {
    private let context: AccountContext
    private let presentationData: PresentationData

    private let titleLabel: UILabel
    private let subtitleLabel: UILabel
    private let scrollView: UIScrollView
    private let stackView: UIStackView
    private let addAccountButton: UIButton
    private let feedButton: UIButton

    private let disposable = MetaDisposable()
    private var latestById: [Int64: (EnginePeer.Id, EngineMessage.Id?)] = [:]

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.titleLabel = UILabel()
        self.subtitleLabel = UILabel()
        self.scrollView = UIScrollView()
        self.stackView = UIStackView()
        self.addAccountButton = UIButton(type: .system)
        self.feedButton = UIButton(type: .system)
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

        self.subtitleLabel.text = "Все подключённые аккаунты, непрочитанные и быстрые действия."
        self.subtitleLabel.font = Font.regular(14.0)
        self.subtitleLabel.textColor = theme.list.itemSecondaryTextColor
        self.subtitleLabel.numberOfLines = 0
        self.view.addSubview(self.subtitleLabel)

        self.scrollView.alwaysBounceVertical = true
        self.view.addSubview(self.scrollView)
        self.stackView.axis = .vertical
        self.stackView.spacing = 10.0
        self.scrollView.addSubview(self.stackView)

        self.feedButton.setTitle("Все непрочитанные", for: .normal)
        self.feedButton.setTitleColor(theme.list.itemAccentColor, for: .normal)
        self.feedButton.titleLabel?.font = Font.semibold(16.0)
        self.feedButton.addTarget(self, action: #selector(self.feedTapped), for: .touchUpInside)
        self.stackView.addArrangedSubview(self.feedButton)

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
                let notificationsSignal = accountContext.engine.data.get(TelegramEngine.EngineData.Item.NotificationSettings.Global())
                let connectionSignal = accountContext.account.network.connectionStatus
                |> take(1)
                let chatListSignal = accountContext.account.viewTracker.tailChatListView(groupId: .root, count: 1)
                |> map { view, _ -> (String?, String?, EnginePeer.Id?, EngineMessage.Id?) in
                    guard let entry = view.entries.first, case let .MessageEntry(data) = entry, let message = data.messages.first else {
                        return (nil, nil, nil, nil)
                    }
                    let strings = accountContext.sharedContext.currentPresentationData.with { $0 }.strings
                    let order = accountContext.sharedContext.currentPresentationData.with { $0 }.nameDisplayOrder
                    let title = data.renderedPeer.peer.flatMap(EnginePeer.init)?.displayTitle(strings: strings, displayOrder: order)
                    let text = message.text.isEmpty ? "[медиа]" : String(message.text.prefix(90))
                    return (title, text, message.id.peerId, message.id)
                }

                return combineLatest(queue: .mainQueue(), peerSignal, countersSignal, notificationsSignal, connectionSignal, chatListSignal)
                |> map { peer, counters, notifications, connection, chatList -> SyncGramAccountPanelItem in
                    let presentationData = accountContext.sharedContext.currentPresentationData.with { $0 }
                    let name = peer?.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder) ?? "Аккаунт"
                    let privateCount = counters.count(for: .raw, in: .messages, with: [.contact, .nonContact])
                    let groups = counters.count(for: .raw, in: .messages, with: .group)
                    let channels = counters.count(for: .raw, in: .messages, with: .channel)
                    let enabled = notifications.privateChats.enabled || notifications.groupChats.enabled || notifications.channels.enabled
                    let connectionText: String
                    switch connection {
                    case .online:
                        connectionText = "Подключён"
                    case .connecting:
                        connectionText = "Подключение…"
                    case .updating:
                        connectionText = "Обновление…"
                    case .waitingForNetwork:
                        connectionText = "Нет сети"
                    }
                    return SyncGramAccountPanelItem(
                        recordId: recordId,
                        title: name,
                        username: peer?.addressName,
                        unreadTotal: privateCount + groups + channels,
                        unreadPrivate: privateCount,
                        unreadGroups: groups,
                        unreadChannels: channels,
                        isActive: primary?.account.id == accountContext.account.id,
                        lastChatTitle: chatList.0,
                        lastMessageText: chatList.1,
                        notificationsEnabled: enabled,
                        mutedUntil: SyncGramAccountSettings.shared.mutedUntil(for: recordId.int64),
                        lastActivity: SyncGramAccountSettings.shared.lastActivity(for: recordId.int64),
                        connectionStatus: connectionText,
                        latestPeerId: chatList.2,
                        latestMessageId: chatList.3
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
        self.currentItems = items
        for view in self.stackView.arrangedSubviews {
            if view !== self.addAccountButton && view !== self.feedButton {
                view.removeFromSuperview()
            }
        }

        self.latestById = [:]
        for item in items {
            if let peerId = item.latestPeerId {
                self.latestById[item.recordId.int64] = (peerId, item.latestMessageId)
            }
        }

        let theme = self.presentationData.theme
        var insertionIndex = 0
        for item in items {
            let container = UIControl()
            let colorIndex = SyncGramAccountSettings.shared.colorIndex(for: item.recordId.int64)
            let accentColors: [UIColor] = [theme.list.itemAccentColor, .systemOrange, .systemGreen, .systemPink, .systemPurple, .systemTeal]
            container.backgroundColor = theme.list.itemBlocksBackgroundColor
            container.layer.cornerRadius = 12.0
            container.layer.borderWidth = colorIndex > 0 ? 2.0 : 0.0
            container.layer.borderColor = accentColors[min(colorIndex, accentColors.count - 1)].cgColor
            container.addTarget(self, action: #selector(self.accountTapped(_:)), for: .touchUpInside)
            container.tag = Int(item.recordId.int64)

            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(self.accountLongPressed(_:)))
            longPress.minimumPressDuration = 0.5
            container.addGestureRecognizer(longPress)

            let emoji = SyncGramAccountSettings.shared.emoji(for: item.recordId.int64)
            let title = UILabel()
            title.text = emoji.isEmpty ? item.title : "\(emoji) \(item.title)"
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

            let lastMessage = UILabel()
            if let lastChatTitle = item.lastChatTitle, let lastMessageText = item.lastMessageText {
                lastMessage.text = "\(lastChatTitle): \(lastMessageText)"
            } else {
                lastMessage.text = "Нет входящих сообщений"
            }
            lastMessage.font = Font.regular(13.0)
            lastMessage.textColor = theme.list.itemSecondaryTextColor
            lastMessage.numberOfLines = 2

            let status = UILabel()
            let notificationText: String
            if let mutedUntil = item.mutedUntil, mutedUntil > Date() {
                notificationText = "Заглушены до \(Self.timeFormatter.string(from: mutedUntil))"
            } else {
                notificationText = item.notificationsEnabled ? "Уведомления включены" : "Уведомления отключены"
            }
            var statusParts = [item.isActive ? "Активен" : "Не активен", item.connectionStatus, notificationText]
            if let lastActivity = item.lastActivity {
                statusParts.append("был \(Self.relativeFormatter.localizedString(for: lastActivity, relativeTo: Date()))")
            }
            status.text = statusParts.joined(separator: " · ")
            status.font = Font.regular(12.0)
            status.textColor = theme.list.itemSecondaryTextColor
            status.numberOfLines = 2

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

            for view in [title, username, categories, lastMessage, status, actions] {
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
                lastMessage.leadingAnchor.constraint(equalTo: title.leadingAnchor),
                lastMessage.trailingAnchor.constraint(equalTo: title.trailingAnchor),
                lastMessage.topAnchor.constraint(equalTo: categories.bottomAnchor, constant: 6.0),
                status.leadingAnchor.constraint(equalTo: title.leadingAnchor),
                status.trailingAnchor.constraint(equalTo: title.trailingAnchor),
                status.topAnchor.constraint(equalTo: lastMessage.bottomAnchor, constant: 4.0),
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
        SyncGramAccountSettings.shared.markActivity(for: id.int64)
        self.context.sharedContext.switchToAccount(id: id, fromSettingsController: nil, withChatListController: nil)
    }

    @objc private func accountLongPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let view = gesture.view as? UIControl else {
            return
        }
        let id = AccountRecordId(rawValue: Int64(view.tag))
        let sheet = UIAlertController(title: "Аккаунт", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Переключиться", style: .default, handler: { [weak self] _ in
            SyncGramAccountSettings.shared.markActivity(for: id.int64)
            self?.context.sharedContext.switchToAccount(id: id, fromSettingsController: nil, withChatListController: nil)
        }))
        if self.latestById[id.int64] != nil {
            sheet.addAction(UIAlertAction(title: "Открыть последнее сообщение", style: .default, handler: { [weak self] _ in
                guard let self, let latest = self.latestById[id.int64] else { return }
                SyncGramAccountSettings.shared.markActivity(for: id.int64)
                self.context.sharedContext.navigateToChat(accountId: id, peerId: latest.0, messageId: latest.1)
            }))
        }
        sheet.addAction(UIAlertAction(title: "Показать непрочитанные", style: .default, handler: { [weak self] _ in
            self?.context.sharedContext.switchToAccount(id: id, fromSettingsController: nil, withChatListController: nil)
        }))
        sheet.addAction(UIAlertAction(title: "Заглушить на 1 час", style: .default, handler: { _ in
            SyncGramAccountSettings.shared.setMutedUntil(Date(timeIntervalSinceNow: 3600.0), for: id.int64)
        }))
        sheet.addAction(UIAlertAction(title: "Скопировать username", style: .default, handler: { [weak self] _ in
            if let item = self?.item(for: id), let username = item.username {
                UIPasteboard.general.string = username
            }
        }))
        sheet.addAction(UIAlertAction(title: "Изменить цвет", style: .default, handler: { [weak self] _ in
            self?.presentColorPicker(for: id)
        }))
        sheet.addAction(UIAlertAction(title: "Изменить иконку", style: .default, handler: { [weak self] _ in
            self?.presentEmojiPicker(for: id)
        }))
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = view.bounds
        }
        self.present(sheet, animated: true, completion: nil)
    }

    private var currentItems: [SyncGramAccountPanelItem] = []

    private func item(for id: AccountRecordId) -> SyncGramAccountPanelItem? {
        return self.currentItems.first(where: { $0.recordId == id })
    }

    private func presentColorPicker(for id: AccountRecordId) {
        let sheet = UIAlertController(title: "Цвет аккаунта", message: nil, preferredStyle: .actionSheet)
        let names = ["По умолчанию", "Оранжевый", "Зелёный", "Розовый", "Фиолетовый", "Бирюзовый"]
        for (index, name) in names.enumerated() {
            sheet.addAction(UIAlertAction(title: name, style: .default, handler: { [weak self] _ in
                SyncGramAccountSettings.shared.setColorIndex(index, for: id.int64)
                self?.reloadVisibleItems()
            }))
        }
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
        self.present(sheet, animated: true, completion: nil)
    }

    private func presentEmojiPicker(for id: AccountRecordId) {
        let sheet = UIAlertController(title: "Иконка аккаунта", message: nil, preferredStyle: .actionSheet)
        for emoji in ["", "💼", "🏠", "⭐️", "🔥", "🎮", "📚"] {
            sheet.addAction(UIAlertAction(title: emoji.isEmpty ? "Без иконки" : emoji, style: .default, handler: { [weak self] _ in
                SyncGramAccountSettings.shared.setEmoji(emoji, for: id.int64)
                self?.reloadVisibleItems()
            }))
        }
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
        self.present(sheet, animated: true, completion: nil)
    }

    private func reloadVisibleItems() {
        self.updateItems(self.currentItems)
    }

    @objc private func openUnreadTapped(_ sender: UIButton) {
        let id = AccountRecordId(rawValue: Int64(sender.tag))
        SyncGramAccountSettings.shared.markActivity(for: id.int64)
        self.context.sharedContext.switchToAccount(id: id, fromSettingsController: nil, withChatListController: nil)
    }

    @objc private func copyUsernameTapped(_ sender: UIButton) {
        if let hint = sender.accessibilityHint {
            UIPasteboard.general.string = hint
        }
    }

    @objc private func addAccountTapped() {
        self.context.sharedContext.beginNewAuth(testingEnvironment: self.context.account.testingEnvironment)
    }

    @objc private func feedTapped() {
        self.present(SyncGramUnreadFeedController(context: self.context), animated: true, completion: nil)
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

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}