import Foundation
import UIKit
import Display
import TelegramCore
import TelegramPresentationData
import AccountContext

/// Local stand-in for the Telegram Premium screen. Nothing here talks to Telegram: it is a
/// cosmetic subscription that unlocks the local SyncGram perks and is stored on the device.
public final class SyncGramLocalPremiumController: ViewController {
    private let context: AccountContext
    private let presentationData: PresentationData

    private let scrollView: UIScrollView
    private let headerView: UIView
    private let headerGradient: CAGradientLayer
    private let logoView: UILabel
    private let titleLabel: UILabel
    private let statusLabel: UILabel
    private let activateButton: UIButton
    private let benefitsTitleLabel: UILabel
    private let benefitsStack: UIStackView
    private let noteLabel: UILabel

    private let benefits: [(icon: String, title: String, subtitle: String)] = [
        ("🚫", "Без рекламы", "Спонсорские сообщения и реклама скрыты."),
        ("👻", "Режим призрака", "Скрывает онлайн, прочтения, набор текста и просмотры Stories."),
        ("🗑", "Удалённые сообщения", "Остаются локально и помечаются значком."),
        ("✏️", "История изменений", "Показывает предыдущие версии отредактированных сообщений."),
        ("🔐", "Защита контента", "Пересылка и сохранение защищённых сообщений."),
        ("📐", "Компактный список", "Уменьшает строки списка чатов, сохраняя ширину."),
        ("🙈", "Скрытие при перевороте", "Блюрит экран после переворота телефона."),
        ("⏳", "Самоуничтожающиеся", "Сообщения с таймером остаются локально.")
    ]

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        self.scrollView = UIScrollView()
        self.headerView = UIView()
        self.headerGradient = CAGradientLayer()
        self.logoView = UILabel()
        self.titleLabel = UILabel()
        self.statusLabel = UILabel()
        self.activateButton = UIButton(type: .system)
        self.benefitsTitleLabel = UILabel()
        self.benefitsStack = UIStackView()
        self.noteLabel = UILabel()

        super.init(navigationBarPresentationData: nil)
        self.title = "SyncGram Premium"
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var accentColor: UIColor {
        return self.presentationData.theme.list.itemAccentColor
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        let theme = self.presentationData.theme
        self.view.backgroundColor = theme.list.plainBackgroundColor

        self.scrollView.alwaysBounceVertical = true
        self.view.addSubview(self.scrollView)

        self.headerView.layer.cornerRadius = 18.0
        self.headerView.clipsToBounds = true
        self.scrollView.addSubview(self.headerView)

        self.headerGradient.colors = [
            self.accentColor.withMultipliedBrightnessBy(0.85).cgColor,
            self.accentColor.cgColor
        ]
        self.headerGradient.startPoint = CGPoint(x: 0.0, y: 0.0)
        self.headerGradient.endPoint = CGPoint(x: 1.0, y: 1.0)
        self.headerView.layer.insertSublayer(self.headerGradient, at: 0)

        self.logoView.text = "S"
        self.logoView.font = Font.bold(34.0)
        self.logoView.textColor = .white
        self.logoView.textAlignment = .center
        self.logoView.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        self.logoView.layer.cornerRadius = 14.0
        self.logoView.clipsToBounds = true
        self.headerView.addSubview(self.logoView)

        self.titleLabel.text = "SyncGram Premium"
        self.titleLabel.font = Font.bold(24.0)
        self.titleLabel.textColor = .white
        self.headerView.addSubview(self.titleLabel)

        self.statusLabel.font = Font.regular(14.0)
        self.statusLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        self.statusLabel.numberOfLines = 2
        self.headerView.addSubview(self.statusLabel)

        self.activateButton.titleLabel?.font = Font.semibold(16.0)
        self.activateButton.setTitleColor(self.accentColor, for: .normal)
        self.activateButton.backgroundColor = .white
        self.activateButton.layer.cornerRadius = 22.0
        self.activateButton.accessibilityLabel = "Активировать локальный премиум"
        self.activateButton.addTarget(self, action: #selector(self.activateTapped), for: .touchUpInside)
        self.headerView.addSubview(self.activateButton)

        self.benefitsTitleLabel.text = "Что входит"
        self.benefitsTitleLabel.font = Font.semibold(17.0)
        self.benefitsTitleLabel.textColor = theme.list.itemPrimaryTextColor
        self.scrollView.addSubview(self.benefitsTitleLabel)

        self.benefitsStack.axis = .vertical
        self.benefitsStack.spacing = 8.0
        self.scrollView.addSubview(self.benefitsStack)

        self.noteLabel.text = "Локальная подписка: работает только на этом устройстве и не меняет статус аккаунта в Telegram."
        self.noteLabel.font = Font.regular(12.0)
        self.noteLabel.textColor = theme.list.itemSecondaryTextColor
        self.noteLabel.numberOfLines = 0
        self.noteLabel.textAlignment = .center
        self.scrollView.addSubview(self.noteLabel)

        self.buildBenefits()
        self.updateState()
    }

    private func buildBenefits() {
        let theme = self.presentationData.theme
        for benefit in self.benefits {
            let container = UIView()
            container.backgroundColor = theme.list.itemBlocksBackgroundColor
            container.layer.cornerRadius = 12.0

            let icon = UILabel()
            icon.text = benefit.icon
            icon.font = Font.regular(22.0)
            icon.textAlignment = .center

            let title = UILabel()
            title.text = benefit.title
            title.font = Font.semibold(15.0)
            title.textColor = theme.list.itemPrimaryTextColor

            let subtitle = UILabel()
            subtitle.text = benefit.subtitle
            subtitle.font = Font.regular(12.0)
            subtitle.textColor = theme.list.itemSecondaryTextColor
            subtitle.numberOfLines = 2

            icon.translatesAutoresizingMaskIntoConstraints = false
            title.translatesAutoresizingMaskIntoConstraints = false
            subtitle.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(icon)
            container.addSubview(title)
            container.addSubview(subtitle)

            NSLayoutConstraint.activate([
                icon.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10.0),
                icon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 34.0),
                title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8.0),
                title.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12.0),
                title.topAnchor.constraint(equalTo: container.topAnchor, constant: 9.0),
                subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
                subtitle.trailingAnchor.constraint(equalTo: title.trailingAnchor),
                subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 2.0),
                subtitle.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -9.0)
            ])

            self.benefitsStack.addArrangedSubview(container)
        }
    }

    private func updateState() {
        let isActive = SyncGramSettings.localPremiumEnabled
        if isActive {
            self.statusLabel.text = "Локально активно\nКосметические функции SyncGram включены на этом устройстве."
            self.activateButton.setTitle("Отключить", for: .normal)
            self.activateButton.accessibilityLabel = "Отключить локальный премиум"
        } else {
            self.statusLabel.text = "Косметическая подписка SyncGram\nВключает локальные функции без изменения аккаунта."
            self.activateButton.setTitle("Активировать", for: .normal)
            self.activateButton.accessibilityLabel = "Активировать локальный премиум"
        }
        self.benefitsStack.alpha = isActive ? 1.0 : 0.85
        self.view.setNeedsLayout()
    }

    @objc private func activateTapped() {
        let isActive = SyncGramSettings.localPremiumEnabled
        SyncGramSettings.localPremiumEnabled = !isActive
        if !isActive {
            // The one tangible perk of the local subscription: no sponsored messages.
            // Remember the previous value so turning the premium off restores it.
            SyncGramSettings.localPremiumPreviousHideAds = SyncGramSettings.hideAdsEnabled
            SyncGramSettings.hideAdsEnabled = true
        } else if let previousHideAds = SyncGramSettings.localPremiumPreviousHideAds {
            SyncGramSettings.hideAdsEnabled = previousHideAds
            SyncGramSettings.localPremiumPreviousHideAds = nil
        }
        NotificationCenter.default.post(name: SyncGramNotificationNames.settingsChanged, object: nil)
        self.updateState()
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let bounds = self.view.bounds
        let insets = self.view.safeAreaInsets
        let width = bounds.width - 32.0

        self.scrollView.frame = CGRect(x: 0.0, y: 0.0, width: bounds.width, height: bounds.height)

        var y: CGFloat = insets.top + 12.0
        let headerHeight: CGFloat = 210.0
        self.headerView.frame = CGRect(x: 16.0, y: y, width: width, height: headerHeight)
        self.headerGradient.frame = self.headerView.bounds
        self.logoView.frame = CGRect(x: 18.0, y: 18.0, width: 58.0, height: 58.0)
        self.titleLabel.frame = CGRect(x: 88.0, y: 22.0, width: width - 104.0, height: 30.0)
        self.statusLabel.frame = CGRect(x: 88.0, y: 54.0, width: width - 104.0, height: 44.0)
        self.activateButton.frame = CGRect(x: 18.0, y: headerHeight - 62.0, width: width - 36.0, height: 44.0)
        y += headerHeight + 18.0

        self.benefitsTitleLabel.frame = CGRect(x: 18.0, y: y, width: width, height: 24.0)
        y += 30.0
        let benefitsHeight = self.benefitsStack.systemLayoutSizeFitting(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        self.benefitsStack.frame = CGRect(x: 16.0, y: y, width: width, height: benefitsHeight)
        y += benefitsHeight + 14.0

        let noteHeight = self.noteLabel.sizeThatFits(CGSize(width: width - 16.0, height: .greatestFiniteMagnitude)).height
        self.noteLabel.frame = CGRect(x: 24.0, y: y, width: width - 16.0, height: noteHeight)
        y += noteHeight + 24.0

        self.scrollView.contentSize = CGSize(width: bounds.width, height: max(y, bounds.height - insets.bottom))
    }
}