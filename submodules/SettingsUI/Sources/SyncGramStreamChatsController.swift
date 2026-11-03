import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import Postbox
import TelegramPresentationData
import AccountContext

private struct SyncGramStreamChatItem {
    let accountId: AccountRecordId
    let accountTitle: String
    let peerId: EnginePeer.Id
    let chatTitle: String
}

public final class SyncGramStreamChatsController: UIViewController {
    private let context: AccountContext
    private let presentationData: PresentationData
    private let titleLabel: UILabel
    private let subtitleLabel: UILabel
    private let scrollView: UIScrollView
    private let stackView: UIStackView
    private let selectAllButton: UIButton
    private let clearButton: UIButton
    private let disposable = MetaDisposable()
    private var items: [SyncGramStreamChatItem] = []

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.titleLabel = UILabel()
        self.subtitleLabel = UILabel()
        self.scrollView = UIScrollView()
        self.stackView = UIStackView()
        self.selectAllButton = UIButton(type: .system)
        self.clearButton = UIButton(type: .system)
        super.init(nibName: nil, bundle: nil)
        self.title = "Чаты для Потока"
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

        self.titleLabel.text = "Чаты для Потока"
        self.titleLabel.font = Font.semibold(20.0)
        self.titleLabel.textColor = theme.list.itemPrimaryTextColor
        self.view.addSubview(self.titleLabel)

        self.subtitleLabel.text = "Отметь чаты, сообщения из которых должны попадать в общую ленту."
        self.subtitleLabel.font = Font.regular(14.0)
        self.subtitleLabel.textColor = theme.list.itemSecondaryTextColor
        self.subtitleLabel.numberOfLines = 0
        self.view.addSubview(self.subtitleLabel)

        self.scrollView.alwaysBounceVertical = true
        self.view.addSubview(self.scrollView)
        self.stackView.axis = .vertical
        self.stackView.spacing = 6.0
        self.scrollView.addSubview(self.stackView)

        self.selectAllButton.setTitle("Выбрать все", for: .normal)
        self.selectAllButton.setTitleColor(theme.list.itemAccentColor, for: .normal)
        self.selectAllButton.titleLabel?.font = Font.semibold(14.0)
        self.selectAllButton.addTarget(self, action: #selector(self.selectAllTapped), for: .touchUpInside)
        self.stackView.addArrangedSubview(self.selectAllButton)

        self.clearButton.setTitle("Снять все", for: .normal)
        self.clearButton.setTitleColor(theme.list.itemDestructiveColor, for: .normal)
        self.clearButton.titleLabel?.font = Font.semibold(14.0)
        self.clearButton.addTarget(self, action: #selector(self.clearTapped), for: .touchUpInside)
        self.stackView.addArrangedSubview(self.clearButton)

        let signal = self.context.sharedContext.activeAccountContexts
        |> mapToSignal { _, accounts, _ -> Signal<[SyncGramStreamChatItem], NoError> in
            let signals: [Signal<[SyncGramStreamChatItem], NoError>] = accounts.map { accountId, accountContext, _ in
                let peerSignal = accountContext.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: accountContext.account.peerId))
                let listSignal = accountContext.account.viewTracker.tailChatListView(groupId: .root, count: 150)
                return combineLatest(queue: .mainQueue(), peerSignal, listSignal)
                |> map { peer, view -> [SyncGramStreamChatItem] in
                    let presentationData = accountContext.sharedContext.currentPresentationData.with { $0 }
                    let accountTitle = peer?.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder) ?? "Аккаунт"
                    var result: [SyncGramStreamChatItem] = []
                    for entry in view.0.entries {
                        guard case let .MessageEntry(data) = entry else { continue }
                        let chatTitle = data.renderedPeer.peer.flatMap(EnginePeer.init)?.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder) ?? "Чат"
                        result.append(SyncGramStreamChatItem(accountId: accountId, accountTitle: accountTitle, peerId: data.renderedPeer.peerId, chatTitle: chatTitle))
                    }
                    return result
                }
            }
            return combineLatest(queue: .mainQueue(), signals)
            |> map { lists -> [SyncGramStreamChatItem] in
                return lists.flatMap { $0 }
            }
        }
        |> deliverOnMainQueue

        self.disposable.set(signal.start(next: { [weak self] items in
            self?.items = items
            self?.rebuild()
        }))
    }

    private func rebuild() {
        for view in self.stackView.arrangedSubviews {
            if view !== self.selectAllButton && view !== self.clearButton {
                view.removeFromSuperview()
            }
        }
        let theme = self.presentationData.theme
        var index = 0
        for item in self.items {
            let selected = SyncGramStreamSettings.shared.isSelected(accountId: item.accountId, peerId: item.peerId)
            let button = UIControl()
            button.backgroundColor = theme.list.itemBlocksBackgroundColor
            button.layer.cornerRadius = 9.0
            button.tag = index
            button.addTarget(self, action: #selector(self.itemTapped(_:)), for: .touchUpInside)

            let title = UILabel()
            title.text = item.chatTitle
            title.font = Font.regular(15.0)
            title.textColor = theme.list.itemPrimaryTextColor

            let subtitle = UILabel()
            subtitle.text = item.accountTitle
            subtitle.font = Font.regular(11.0)
            subtitle.textColor = theme.list.itemSecondaryTextColor

            let check = UILabel()
            check.text = selected ? "✓" : ""
            check.font = Font.semibold(16.0)
            check.textColor = theme.list.itemAccentColor
            check.textAlignment = .right

            for view in [title, subtitle, check] {
                view.translatesAutoresizingMaskIntoConstraints = false
                button.addSubview(view)
            }
            NSLayoutConstraint.activate([
                title.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 12.0),
                title.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -40.0),
                title.topAnchor.constraint(equalTo: button.topAnchor, constant: 7.0),
                subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
                subtitle.trailingAnchor.constraint(equalTo: title.trailingAnchor),
                subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 1.0),
                subtitle.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -7.0),
                check.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -12.0),
                check.centerYAnchor.constraint(equalTo: button.centerYAnchor)
            ])
            self.stackView.insertArrangedSubview(button, at: index)
            index += 1
        }
    }

    @objc private func itemTapped(_ sender: UIControl) {
        guard sender.tag >= 0 && sender.tag < self.items.count else {
            return
        }
        let item = self.items[sender.tag]
        let selected = SyncGramStreamSettings.shared.isSelected(accountId: item.accountId, peerId: item.peerId)
        SyncGramStreamSettings.shared.setSelected(!selected, accountId: item.accountId, peerId: item.peerId)
        self.rebuild()
    }

    @objc private func selectAllTapped() {
        for item in self.items {
            SyncGramStreamSettings.shared.setSelected(true, accountId: item.accountId, peerId: item.peerId)
        }
        self.rebuild()
    }

    @objc private func clearTapped() {
        SyncGramStreamSettings.shared.clear()
        self.rebuild()
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let bounds = self.view.bounds
        let insets = self.view.safeAreaInsets
        let width = bounds.width - 40.0
        self.titleLabel.frame = CGRect(x: 20.0, y: insets.top + 16.0, width: width, height: 28.0)
        self.subtitleLabel.frame = CGRect(x: 20.0, y: insets.top + 50.0, width: width, height: 40.0)
        let top = insets.top + 98.0
        self.scrollView.frame = CGRect(x: 20.0, y: top, width: width, height: bounds.height - top - insets.bottom - 16.0)
        let height = self.stackView.systemLayoutSizeFitting(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        self.stackView.frame = CGRect(x: 0.0, y: 0.0, width: width, height: height)
        self.scrollView.contentSize = CGSize(width: width, height: height)
    }
}