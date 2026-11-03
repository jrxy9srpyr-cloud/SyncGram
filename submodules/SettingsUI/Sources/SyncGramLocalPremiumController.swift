import Foundation
import UIKit
import Display
import TelegramCore
import TelegramPresentationData
import AccountContext

public final class SyncGramLocalPremiumController: ViewController {
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
        self.title = "Локальный премиум"
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        let theme = self.presentationData.theme
        self.view.backgroundColor = theme.list.plainBackgroundColor

        self.titleLabel.text = "Локальный премиум"
        self.titleLabel.font = Font.semibold(20.0)
        self.titleLabel.textColor = theme.list.itemPrimaryTextColor
        self.view.addSubview(self.titleLabel)

        self.descriptionLabel.text = "Этот раздел не меняет статус аккаунта и не выдаёт ложный Telegram Premium. Здесь собраны косметические и локальные функции SyncGram."
        self.descriptionLabel.font = Font.regular(14.0)
        self.descriptionLabel.textColor = theme.list.itemSecondaryTextColor
        self.descriptionLabel.numberOfLines = 0
        self.view.addSubview(self.descriptionLabel)

        self.scrollView.alwaysBounceVertical = true
        self.view.addSubview(self.scrollView)

        self.stackView.axis = .vertical
        self.stackView.spacing = 8.0
        self.scrollView.addSubview(self.stackView)

        let features: [(String, String)] = [
            ("Ghost mode", "Удалённые сообщения остаются локально и помечаются."),
            ("История редактирования", "Показывает предыдущие версии изменённого текста."),
            ("Самоуничтожающиеся сообщения", "Остаются локально после истечения срока."),
            ("Обход защиты", "Пересылка и сохранение защищённого контента."),
            ("Скриншоты в секретах", "Без уведомления собеседнику."),
            ("Режим призрака", "Скрывает онлайн, прочтения, набор текста и просмотры Stories."),
            ("Компактный список чатов", "Уменьшает строки списка чатов."),
            ("Скрытие при перевороте", "Прячет интерфейс, когда телефон лежит экраном вниз.")
        ]

        for feature in features {
            let container = UIView()
            container.backgroundColor = theme.list.itemBlocksBackgroundColor
            container.layer.cornerRadius = 12.0

            let title = UILabel()
            title.text = feature.0
            title.font = Font.semibold(16.0)
            title.textColor = theme.list.itemPrimaryTextColor

            let subtitle = UILabel()
            subtitle.text = feature.1
            subtitle.font = Font.regular(13.0)
            subtitle.textColor = theme.list.itemSecondaryTextColor
            subtitle.numberOfLines = 0

            container.addSubview(title)
            container.addSubview(subtitle)
            title.translatesAutoresizingMaskIntoConstraints = false
            subtitle.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14.0),
                title.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14.0),
                title.topAnchor.constraint(equalTo: container.topAnchor, constant: 10.0),
                subtitle.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14.0),
                subtitle.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14.0),
                subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 3.0),
                subtitle.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10.0)
            ])

            self.stackView.addArrangedSubview(container)
        }
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let bounds = self.view.bounds
        let insets = self.view.safeAreaInsets
        let contentWidth = bounds.width - 40.0
        let top = insets.top + 16.0

        self.titleLabel.frame = CGRect(x: 20.0, y: top, width: contentWidth, height: 28.0)
        self.descriptionLabel.frame = CGRect(x: 20.0, y: top + 34.0, width: contentWidth, height: 64.0)

        let scrollTop = top + 106.0
        self.scrollView.frame = CGRect(x: 20.0, y: scrollTop, width: contentWidth, height: bounds.height - scrollTop - insets.bottom - 16.0)
        self.stackView.frame = CGRect(x: 0.0, y: 0.0, width: contentWidth, height: self.stackView.systemLayoutSizeFitting(CGSize(width: contentWidth, height: .greatestFiniteMagnitude)).height)
        self.scrollView.contentSize = self.stackView.frame.size
    }
}