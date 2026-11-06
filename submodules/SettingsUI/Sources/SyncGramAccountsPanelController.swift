import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import Postbox
import TelegramPresentationData
import SyncGramUI
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


private final class SyncGramAccountRowView {
    let container: UIControl
    let title: UILabel
    let username: UILabel
    let categories: UILabel
    let lastMessage: UILabel
    let status: UILabel
    let actions: UIStackView
    let openButton: UIButton
    let copyButton: UIButton

    init(theme: PresentationTheme) {
        self.container = UIControl()
        self.title = UILabel()
        self.username = UILabel()
        self.categories = UILabel()
        self.lastMessage = UILabel()
        self.status = UILabel()
        self.actions = UIStackView()
        self.openButton = UIButton(type: .system)
        self.copyButton = UIButton(type: .system)

        self.container.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.container.layer.cornerRadius = 12.0
        // Keep every child inside the card: a long action title must never paint past the tile.
        self.container.clipsToBounds = true

        self.title.font = Font.semibold(17.0)
        self.title.textColor = theme.list.itemPrimaryTextColor
        self.title.numberOfLines = 1

        self.username.font = Font.regular(14.0)
        self.username.textColor = theme.list.itemSecondaryTextColor
        self.username.numberOfLines = 1

        self.categories.font = Font.regular(13.0)
        self.categories.textColor = theme.list.itemSecondaryTextColor
        self.categories.numberOfLines = 1

        self.lastMessage.font = Font.regular(13.0)
        self.lastMessage.textColor = theme.list.itemSecondaryTextColor
        self.lastMessage.numberOfLines = 2

        self.status.font = Font.regular(12.0)
        self.status.textColor = theme.list.itemSecondaryTextColor
        self.status.numberOfLines = 2

        self.actions.axis = .horizontal
        self.actions.spacing = 8.0
        // Fill the card's width instead of hugging the two long button titles: with a
        // `lessThanOrEqual` trailing constraint the stack could grow past the card edge and the
        // whole settings tile looked wider than the screen.
        self.actions.distribution = .fillEqually
        self.actions.alignment = .center

        self.openButton.setTitle("Непрочитанные", for: .normal)
        self.openButton.setTitleColor(theme.list.itemAccentColor, for: .normal)
        self.openButton.titleLabel?.font = Font.semibold(13.0)
        self.openButton.titleLabel?.adjustsFontSizeToFitWidth = true
        self.openButton.titleLabel?.minimumScaleFactor = 0.7
        self.openButton.titleLabel?.lineBreakMode = .byTruncatingTail
        self.openButton.accessibilityLabel = "Открыть непрочитанные"

        self.copyButton.setTitle("Username", for: .normal)
        self.copyButton.setTitleColor(theme.list.itemAccentColor, for: .normal)
        self.copyButton.titleLabel?.font = Font.regular(13.0)
        self.copyButton.titleLabel?.adjustsFontSizeToFitWidth = true
        self.copyButton.titleLabel?.minimumScaleFactor = 0.7
        self.copyButton.titleLabel?.lineBreakMode = .byTruncatingTail
        self.copyButton.accessibilityLabel = "Скопировать username"

        self.openButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        self.copyButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        self.actions.addArrangedSubview(self.openButton)
        self.actions.addArrangedSubview(self.copyButton)

        for view in [self.title, self.username, self.categories, self.lastMessage, self.status, self.actions] {
            view.translatesAutoresizingMaskIntoConstraints = false
            self.container.addSubview(view)
        }

        NSLayoutConstraint.activate([
            self.title.leadingAnchor.constraint(equalTo: self.container.leadingAnchor, constant: 14.0),
            self.title.trailingAnchor.constraint(equalTo: self.container.trailingAnchor, constant: -14.0),
            self.title.topAnchor.constraint(equalTo: self.container.topAnchor, constant: 12.0),
            self.username.leadingAnchor.constraint(equalTo: self.title.leadingAnchor),
            self.username.trailingAnchor.constraint(equalTo: self.title.trailingAnchor),
            self.username.topAnchor.constraint(equalTo: self.title.bottomAnchor, constant: 2.0),
            self.categories.leadingAnchor.constraint(equalTo: self.title.leadingAnchor),
            self.categories.trailingAnchor.constraint(equalTo: self.title.trailingAnchor),
            self.categories.topAnchor.constraint(equalTo: self.username.bottomAnchor, constant: 2.0),
            self.lastMessage.leadingAnchor.constraint(equalTo: self.title.leadingAnchor),
            self.lastMessage.trailingAnchor.constraint(equalTo: self.title.trailingAnchor),
            self.lastMessage.topAnchor.constraint(equalTo: self.categories.bottomAnchor, constant: 6.0),
            self.status.leadingAnchor.constraint(equalTo: self.title.leadingAnchor),
            self.status.trailingAnchor.constraint(equalTo: self.title.trailingAnchor),
            self.status.topAnchor.constraint(equalTo: self.lastMessage.bottomAnchor, constant: 4.0),
            self.actions.leadingAnchor.constraint(equalTo: self.title.leadingAnchor),
            self.actions.trailingAnchor.constraint(equalTo: self.container.trailingAnchor, constant: -14.0),
            self.actions.topAnchor.constraint(equalTo: self.status.bottomAnchor, constant: 8.0),
            self.actions.bottomAnchor.constraint(equalTo: self.container.bottomAnchor, constant: -12.0)
        ])
    }
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
    private var usernameById: [Int64: String] = [:]
    private var hasLoaded = false
    private let skeletonView = SyncGramSkeletonView(style: SyncGramSkeletonView.Style(rows: 4, rowHeight: 96.0, avatarSize: 40.0, horizontalInset: 4.0, topInset: 4.0, barHeight: 12.0, barSpacing: 8.0))

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.titleLabel = UILabel()
        self.subtitleLabel = UILabel()
        self.scrollView = UIScrollView()
        self.stackView = UIStackView()
        self.addAccountButton = UIButton(type: .system)
        self.feedButton = UIButton(type: .system)
        super.init(navigationBarPresentationData: nil)
        self.title = "Аккаунты"
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
        self.view.addSubview(self.skeletonView)
        self.skeletonView.update(isDark: theme.overallDarkAppearance)
        self.skeletonView.setAnimating(true)
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

    private var accountRows: [Int64: SyncGramAccountRowView] = [:]

    private func updateItems(_ items: [SyncGramAccountPanelItem]) {
        self.currentItems = items
        self.hasLoaded = true
        self.skeletonView.isHidden = true
        self.skeletonView.setAnimating(false)

        self.latestById = [:]
        for item in items {
            if let peerId = item.latestPeerId {
                self.latestById[item.recordId.int64] = (peerId, item.latestMessageId)
            }
        }

        // Remove rows for accounts that are gone, keep the rest and update them in place so
        // a refresh (unread counters, status) does not rebuild and flicker the whole list.
        let ids = Set(items.map({ $0.recordId.int64 }))
        let staleIds = self.accountRows.keys.filter({ !ids.contains($0) })
        for id in staleIds {
            if let row = self.accountRows.removeValue(forKey: id) {
                row.container.removeFromSuperview()
            }
        }

        let theme = self.presentationData.theme
        let accentColors: [UIColor] = [theme.list.itemAccentColor, .systemOrange, .systemGreen, .systemPink, .systemPurple, .systemTeal]

        for (index, item) in items.enumerated() {
            let row: SyncGramAccountRowView
            if let existing = self.accountRows[item.recordId.int64] {
                row = existing
            } else {
                row = SyncGramAccountRowView(theme: theme)
                row.container.tag = Int(item.recordId.int64)
                row.container.addTarget(self, action: #selector(self.accountTapped(_:)), for: .touchUpInside)
                row.openButton.tag = Int(item.recordId.int64)
                row.openButton.addTarget(self, action: #selector(self.openUnreadTapped(_:)), for: .touchUpInside)
                row.copyButton.tag = Int(item.recordId.int64)
                row.copyButton.addTarget(self, action: #selector(self.copyUsernameTapped(_:)), for: .touchUpInside)

                let longPress = UILongPressGestureRecognizer(target: self, action: #selector(self.accountLongPressed(_:)))
                longPress.minimumPressDuration = 0.5
                row.container.addGestureRecognizer(longPress)

                self.accountRows[item.recordId.int64] = row
                self.stackView.insertArrangedSubview(row.container, at: index)
            }

            let colorIndex = SyncGramAccountSettings.shared.colorIndex(for: item.recordId.int64)
            row.container.layer.borderWidth = colorIndex > 0 ? 2.0 : 0.0
            row.container.layer.borderColor = accentColors[min(colorIndex, accentColors.count - 1)].cgColor

            let emoji = SyncGramAccountSettings.shared.emoji(for: item.recordId.int64)
            row.title.text = emoji.isEmpty ? item.title : "\(emoji) \(item.title)"
            row.username.text = "@\(item.username ?? "—") · \(item.unreadTotal) непрочитанных"
            if let username = item.username {
                self.usernameById[item.recordId.int64] = username
            } else {
                self.usernameById.removeValue(forKey: item.recordId.int64)
            }
            row.categories.text = "\(item.unreadPrivate) личных · \(item.unreadGroups) групп · \(item.unreadChannels) каналов"
            if let lastChatTitle = item.lastChatTitle, let lastMessageText = item.lastMessageText {
                row.lastMessage.text = "\(lastChatTitle): \(lastMessageText)"
            } else {
                row.lastMessage.text = "Нет входящих сообщений"
            }

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
            row.status.text = statusParts.joined(separator: " · ")

            row.openButton.isHidden = item.unreadTotal <= 0
            row.copyButton.isHidden = item.username == nil
        }

        self.view.setNeedsLayout()
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
        guard let username = self.usernameById[Int64(sender.tag)], !username.isEmpty else {
            return
        }
        UIPasteboard.general.string = "@\(username)"
        SyncGramToast.show("Username @\(username) скопирован")
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
        let subtitleHeight = self.subtitleLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        self.subtitleLabel.frame = CGRect(x: 20.0, y: top + 34.0, width: width, height: subtitleHeight)

        let scrollTop = top + 34.0 + subtitleHeight + 14.0
        self.scrollView.frame = CGRect(x: 20.0, y: scrollTop, width: width, height: bounds.height - scrollTop - insets.bottom - 16.0)
        self.skeletonView.frame = self.scrollView.frame
        self.skeletonView.isHidden = self.hasLoaded
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