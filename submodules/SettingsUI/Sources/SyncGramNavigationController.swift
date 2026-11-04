import Foundation
import UIKit
import Display
import TelegramCore
import TelegramPresentationData
import AccountContext

public final class SyncGramNavigationController: ViewController {
    private let context: AccountContext
    private let presentationData: PresentationData

    private let titleLabel: UILabel
    private let descriptionLabel: UILabel
    private let scrollView: UIScrollView
    private let stackView: UIStackView

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.titleLabel = UILabel()
        self.descriptionLabel = UILabel()
        self.scrollView = UIScrollView()
        self.stackView = UIStackView()
        super.init(navigationBarPresentationData: nil)
        self.title = "Навигация"
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        let theme = self.presentationData.theme
        self.view.backgroundColor = theme.list.plainBackgroundColor

        self.titleLabel.text = "Навигация"
        self.titleLabel.font = Font.semibold(20.0)
        self.titleLabel.textColor = theme.list.itemPrimaryTextColor
        self.view.addSubview(self.titleLabel)

        self.descriptionLabel.text = "Выбери, где находится вкладка: снизу, доступна свайпом или скрыта. Изменения применяются сразу."
        self.descriptionLabel.font = Font.regular(14.0)
        self.descriptionLabel.textColor = theme.list.itemSecondaryTextColor
        self.descriptionLabel.numberOfLines = 0
        self.view.addSubview(self.descriptionLabel)

        self.scrollView.alwaysBounceVertical = true
        self.view.addSubview(self.scrollView)
        self.stackView.axis = .vertical
        self.stackView.spacing = 10.0
        self.scrollView.addSubview(self.stackView)

        for tab in SyncGramTabId.allCases {
            let container = UIView()
            container.backgroundColor = theme.list.itemBlocksBackgroundColor
            container.layer.cornerRadius = 12.0

            let label = UILabel()
            label.text = tab.title
            label.font = Font.semibold(16.0)
            label.textColor = theme.list.itemPrimaryTextColor
            label.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(label)

            let control = UISegmentedControl(items: ["Снизу", "Свайп", "Скрыть"])
            control.selectedSegmentIndex = Self.index(for: SyncGramNavigationSettings.shared.placement(for: tab))
            control.tag = SyncGramTabId.allCases.firstIndex(of: tab) ?? 0
            control.addTarget(self, action: #selector(self.segmentChanged(_:)), for: .valueChanged)
            control.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(control)

            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14.0),
                label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14.0),
                label.topAnchor.constraint(equalTo: container.topAnchor, constant: 10.0),
                control.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10.0),
                control.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10.0),
                control.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 6.0),
                control.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10.0)
            ])

            self.stackView.addArrangedSubview(container)
        }
    }

    private static func index(for placement: SyncGramTabPlacement) -> Int {
        switch placement {
        case .bottom, .top:
            return 0
        case .swipe:
            return 1
        case .hidden:
            return 2
        }
    }

    private static func placement(for index: Int) -> SyncGramTabPlacement {
        switch index {
        case 1:
            return .swipe
        case 2:
            return .hidden
        default:
            return .bottom
        }
    }

    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        guard sender.tag >= 0 && sender.tag < SyncGramTabId.allCases.count else {
            return
        }
        let tab = SyncGramTabId.allCases[sender.tag]
        SyncGramNavigationSettings.shared.setPlacement(Self.placement(for: sender.selectedSegmentIndex), for: tab)
        NotificationCenter.default.post(name: Notification.Name("SyncGramNavigationChanged"), object: nil)
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let bounds = self.view.bounds
        let insets = self.view.safeAreaInsets
        let width = bounds.width - 40.0
        let top = insets.top + 16.0

        self.titleLabel.frame = CGRect(x: 20.0, y: top, width: width, height: 28.0)
        let descriptionHeight = self.descriptionLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        self.descriptionLabel.frame = CGRect(x: 20.0, y: top + 34.0, width: width, height: descriptionHeight)

        let scrollTop = top + 34.0 + descriptionHeight + 14.0
        self.scrollView.frame = CGRect(x: 20.0, y: scrollTop, width: width, height: bounds.height - scrollTop - insets.bottom - 16.0)
        let height = self.stackView.systemLayoutSizeFitting(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        self.stackView.frame = CGRect(x: 0.0, y: 0.0, width: width, height: height)
        self.scrollView.contentSize = CGSize(width: width, height: height)
    }
}