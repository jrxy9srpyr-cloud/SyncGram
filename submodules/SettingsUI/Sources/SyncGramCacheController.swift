import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext

public final class SyncGramCacheController: ViewController {
    private let context: AccountContext
    private let presentationData: PresentationData
    private let titleLabel: UILabel
    private let subtitleLabel: UILabel
    private let scrollView: UIScrollView
    private let stackView: UIStackView
    private let clearButton: UIButton
    private let disposable = MetaDisposable()

    private var selectedCategories: Set<StorageUsageStats.CategoryKey> = []
    private var latestStats: AllStorageUsageStats?

    private let categories: [StorageUsageStats.CategoryKey] = [.photos, .videos, .files, .music, .stickers, .avatars, .misc, .stories]

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.titleLabel = UILabel()
        self.subtitleLabel = UILabel()
        self.scrollView = UIScrollView()
        self.stackView = UIStackView()
        self.clearButton = UIButton(type: .system)
        super.init(navigationBarPresentationData: nil)
        self.title = "Умное управление кэшем"
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

        self.titleLabel.text = "Умное управление кэшем"
        self.titleLabel.font = Font.semibold(20.0)
        self.titleLabel.textColor = theme.list.itemPrimaryTextColor
        self.view.addSubview(self.titleLabel)

        self.subtitleLabel.text = "Выбери категории медиа и очисти только их. Ниже — чаты, которые занимают больше всего места."
        self.subtitleLabel.font = Font.regular(14.0)
        self.subtitleLabel.textColor = theme.list.itemSecondaryTextColor
        self.subtitleLabel.numberOfLines = 0
        self.view.addSubview(self.subtitleLabel)

        self.scrollView.alwaysBounceVertical = true
        self.view.addSubview(self.scrollView)
        self.stackView.axis = .vertical
        self.stackView.spacing = 8.0
        self.scrollView.addSubview(self.stackView)

        self.clearButton.setTitle("Очистить выбранные категории", for: .normal)
        self.clearButton.setTitleColor(theme.list.itemDestructiveColor, for: .normal)
        self.clearButton.titleLabel?.font = Font.semibold(15.0)
        self.clearButton.addTarget(self, action: #selector(self.clearTapped), for: .touchUpInside)
        self.stackView.addArrangedSubview(self.clearButton)

        self.reload()
    }

    private func reload() {
        self.disposable.set((self.context.engine.resources.collectStorageUsageStats()
        |> deliverOnMainQueue).start(next: { [weak self] stats in
            self?.latestStats = stats
            self?.rebuild()
        }))
    }

    private func rebuild() {
        for view in self.stackView.arrangedSubviews {
            if view !== self.clearButton {
                view.removeFromSuperview()
            }
        }
        guard let stats = self.latestStats else {
            return
        }
        let theme = self.presentationData.theme
        let total = stats.totalStats.categories.values.reduce(Int64(0), { $0 + $1.size })

        let totalLabel = UILabel()
        totalLabel.text = "Всего кэша: \(Self.formatSize(total)) · свободно: \(Self.formatSize(stats.deviceFreeSpace))"
        totalLabel.font = Font.semibold(15.0)
        totalLabel.textColor = theme.list.itemPrimaryTextColor
        self.stackView.insertArrangedSubview(totalLabel, at: 0)

        var index = 1
        for category in self.categories {
            let size = stats.totalStats.categories[category]?.size ?? 0
            let button = UIControl()
            button.backgroundColor = theme.list.itemBlocksBackgroundColor
            button.layer.cornerRadius = 10.0
            button.tag = self.categoryTag(category)
            button.addTarget(self, action: #selector(self.categoryTapped(_:)), for: .touchUpInside)

            let title = UILabel()
            title.text = "\(self.title(for: category)) — \(Self.formatSize(size))"
            title.font = Font.regular(15.0)
            title.textColor = theme.list.itemPrimaryTextColor
            title.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(title)

            let check = UILabel()
            check.text = self.selectedCategories.contains(category) ? "✓" : ""
            check.font = Font.semibold(16.0)
            check.textColor = theme.list.itemAccentColor
            check.textAlignment = .right
            check.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(check)

            NSLayoutConstraint.activate([
                title.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 12.0),
                title.trailingAnchor.constraint(lessThanOrEqualTo: check.leadingAnchor, constant: -8.0),
                title.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                check.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -12.0),
                check.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                button.heightAnchor.constraint(equalToConstant: 44.0)
            ])
            self.stackView.insertArrangedSubview(button, at: index)
            index += 1
        }

        let peers = stats.peers.values.sorted(by: {
            let l = $0.stats.categories.values.reduce(Int64(0), { $0 + $1.size })
            let r = $1.stats.categories.values.reduce(Int64(0), { $0 + $1.size })
            return l > r
        })
        for peer in peers.prefix(12) {
            let size = peer.stats.categories.values.reduce(Int64(0), { $0 + $1.size })
            if size <= 0 {
                continue
            }
            let button = UIControl()
            button.backgroundColor = theme.list.itemBlocksBackgroundColor
            button.layer.cornerRadius = 10.0
            button.tag = Int(peer.peer.id.toInt64())
            button.addTarget(self, action: #selector(self.peerTapped(_:)), for: .touchUpInside)

            let title = UILabel()
            title.text = "\(peer.peer.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)) — \(Self.formatSize(size))"
            title.font = Font.regular(14.0)
            title.textColor = theme.list.itemPrimaryTextColor
            title.numberOfLines = 2
            title.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(title)

            let hint = UILabel()
            hint.text = "Очистить чат"
            hint.font = Font.semibold(12.0)
            hint.textColor = theme.list.itemAccentColor
            hint.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(hint)

            NSLayoutConstraint.activate([
                title.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 12.0),
                title.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -100.0),
                title.topAnchor.constraint(equalTo: button.topAnchor, constant: 9.0),
                title.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -9.0),
                hint.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -12.0),
                hint.centerYAnchor.constraint(equalTo: button.centerYAnchor)
            ])
            self.stackView.insertArrangedSubview(button, at: index)
            index += 1
        }
        self.view.setNeedsLayout()
    }

    private func categoryTag(_ category: StorageUsageStats.CategoryKey) -> Int {
        switch category {
        case .photos: return 1
        case .videos: return 2
        case .files: return 3
        case .music: return 4
        case .stickers: return 5
        case .avatars: return 6
        case .misc: return 7
        case .stories: return 8
        }
    }

    private func category(for tag: Int) -> StorageUsageStats.CategoryKey? {
        switch tag {
        case 1: return .photos
        case 2: return .videos
        case 3: return .files
        case 4: return .music
        case 5: return .stickers
        case 6: return .avatars
        case 7: return .misc
        case 8: return .stories
        default: return nil
        }
    }

    private func title(for category: StorageUsageStats.CategoryKey) -> String {
        switch category {
        case .photos: return "Фото"
        case .videos: return "Видео"
        case .files: return "Файлы"
        case .music: return "Музыка"
        case .stickers: return "Стикеры"
        case .avatars: return "Аватары"
        case .misc: return "Прочее"
        case .stories: return "Истории"
        }
    }

    @objc private func categoryTapped(_ sender: UIControl) {
        guard let category = self.category(for: sender.tag) else { return }
        if self.selectedCategories.contains(category) {
            self.selectedCategories.remove(category)
        } else {
            self.selectedCategories.insert(category)
        }
        self.rebuild()
    }

    @objc private func clearTapped() {
        guard !self.selectedCategories.isEmpty else {
            return
        }
        let categories = Array(self.selectedCategories)
        self.disposable.set((self.context.engine.resources.clearStorage(peerId: nil, categories: categories, includeMessages: [], excludeMessages: [])
        |> deliverOnMainQueue).start(completed: { [weak self] in
            self?.selectedCategories = []
            self?.reload()
        }))
    }

    @objc private func peerTapped(_ sender: UIControl) {
        let peerId = EnginePeer.Id(Int64(sender.tag))
        let categories = self.categories
        self.disposable.set((self.context.engine.resources.clearStorage(peerId: peerId, categories: categories, includeMessages: [], excludeMessages: [])
        |> deliverOnMainQueue).start(completed: { [weak self] in
            self?.reload()
        }))
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
    }

    private static func formatSize(_ value: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: value)
    }
}