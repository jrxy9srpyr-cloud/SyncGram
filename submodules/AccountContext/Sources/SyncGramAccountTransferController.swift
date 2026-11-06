import Foundation
import UIKit

/// Progress screen shown while an imported session is being attached to the account manager.
/// It turns the previously invisible wait into three honest steps, so the user never sees an
/// empty chat list with a bare «Обновление…».
public final class SyncGramAccountTransferController: UIViewController {
    private let card = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let stepsStack = UIStackView()
    private let doneButton = UIButton(type: .system)

    private var stepRows: [(circle: UIView, label: UILabel)] = []
    public var onClose: (() -> Void)?

    public init() {
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .overFullScreen
        self.modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = UIColor.black.withAlphaComponent(0.35)

        self.card.backgroundColor = .secondarySystemBackground
        self.card.layer.cornerRadius = 20.0
        self.card.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.card)

        self.titleLabel.text = "Перенос аккаунта"
        self.titleLabel.font = .systemFont(ofSize: 20.0, weight: .semibold)
        self.titleLabel.textColor = .label
        self.titleLabel.textAlignment = .center
        self.titleLabel.numberOfLines = 0
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.card.addSubview(self.titleLabel)

        self.subtitleLabel.text = "Обычно это занимает 5–20 секунд. Не закрывайте приложение."
        self.subtitleLabel.font = .systemFont(ofSize: 14.0)
        self.subtitleLabel.textColor = .secondaryLabel
        self.subtitleLabel.textAlignment = .center
        self.subtitleLabel.numberOfLines = 0
        self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.card.addSubview(self.subtitleLabel)

        self.stepsStack.axis = .vertical
        self.stepsStack.spacing = 12.0
        self.stepsStack.alignment = .fill
        self.stepsStack.translatesAutoresizingMaskIntoConstraints = false
        self.card.addSubview(self.stepsStack)

        for title in ["Читаем файл сессии", "Добавляем аккаунт", "Загружаем чаты"] {
            let row = UIView()
            let circle = UIView()
            circle.layer.cornerRadius = 9.0
            circle.backgroundColor = .tertiaryLabel
            circle.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(circle)

            let label = UILabel()
            label.text = title
            label.font = .systemFont(ofSize: 15.0)
            label.textColor = .secondaryLabel
            label.numberOfLines = 0
            label.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(label)

            NSLayoutConstraint.activate([
                circle.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                circle.centerYAnchor.constraint(equalTo: label.centerYAnchor),
                circle.widthAnchor.constraint(equalToConstant: 18.0),
                circle.heightAnchor.constraint(equalToConstant: 18.0),

                label.leadingAnchor.constraint(equalTo: circle.trailingAnchor, constant: 12.0),
                label.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                label.topAnchor.constraint(equalTo: row.topAnchor),
                label.bottomAnchor.constraint(equalTo: row.bottomAnchor)
            ])
            self.stepsStack.addArrangedSubview(row)
            self.stepRows.append((circle, label))
        }

        self.doneButton.setTitle("Готово", for: .normal)
        self.doneButton.titleLabel?.font = .systemFont(ofSize: 16.0, weight: .semibold)
        self.doneButton.backgroundColor = .systemBlue
        self.doneButton.setTitleColor(.white, for: .normal)
        self.doneButton.layer.cornerRadius = 12.0
        self.doneButton.translatesAutoresizingMaskIntoConstraints = false
        self.doneButton.addTarget(self, action: #selector(self.donePressed), for: .touchUpInside)
        self.doneButton.isHidden = true
        self.card.addSubview(self.doneButton)

        let cardWidth = self.card.widthAnchor.constraint(equalToConstant: 340.0)
        cardWidth.priority = .defaultHigh

        NSLayoutConstraint.activate([
            self.card.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            self.card.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
            self.card.leadingAnchor.constraint(greaterThanOrEqualTo: self.view.leadingAnchor, constant: 24.0),
            self.card.trailingAnchor.constraint(lessThanOrEqualTo: self.view.trailingAnchor, constant: -24.0),
            cardWidth,

            self.titleLabel.topAnchor.constraint(equalTo: self.card.topAnchor, constant: 24.0),
            self.titleLabel.leadingAnchor.constraint(equalTo: self.card.leadingAnchor, constant: 24.0),
            self.titleLabel.trailingAnchor.constraint(equalTo: self.card.trailingAnchor, constant: -24.0),

            self.subtitleLabel.topAnchor.constraint(equalTo: self.titleLabel.bottomAnchor, constant: 8.0),
            self.subtitleLabel.leadingAnchor.constraint(equalTo: self.card.leadingAnchor, constant: 24.0),
            self.subtitleLabel.trailingAnchor.constraint(equalTo: self.card.trailingAnchor, constant: -24.0),

            self.stepsStack.topAnchor.constraint(equalTo: self.subtitleLabel.bottomAnchor, constant: 20.0),
            self.stepsStack.leadingAnchor.constraint(equalTo: self.card.leadingAnchor, constant: 24.0),
            self.stepsStack.trailingAnchor.constraint(equalTo: self.card.trailingAnchor, constant: -24.0),

            self.doneButton.topAnchor.constraint(equalTo: self.stepsStack.bottomAnchor, constant: 22.0),
            self.doneButton.leadingAnchor.constraint(equalTo: self.card.leadingAnchor, constant: 24.0),
            self.doneButton.trailingAnchor.constraint(equalTo: self.card.trailingAnchor, constant: -24.0),
            self.doneButton.heightAnchor.constraint(equalToConstant: 46.0),
            self.doneButton.bottomAnchor.constraint(equalTo: self.card.bottomAnchor, constant: -20.0)
        ])

        self.update(step: .creatingAccount)
        UIAccessibility.post(notification: .screenChanged, argument: self.titleLabel)
    }

    public func update(step: SyncGramAccountTransferStep) {
        self.loadViewIfNeeded()

        func style(_ index: Int, state: StepState) {
            guard index < self.stepRows.count else {
                return
            }
            let row = self.stepRows[index]
            switch state {
            case .pending:
                row.circle.backgroundColor = .tertiaryLabel
                row.label.textColor = .secondaryLabel
            case .active:
                row.circle.backgroundColor = .systemBlue
                row.label.textColor = .label
                row.circle.layer.removeAnimation(forKey: "pulse")
                let animation = CABasicAnimation(keyPath: "opacity")
                animation.fromValue = 1.0
                animation.toValue = 0.35
                animation.duration = 0.7
                animation.autoreverses = true
                animation.repeatCount = .infinity
                row.circle.layer.add(animation, forKey: "pulse")
            case .done:
                row.circle.layer.removeAnimation(forKey: "pulse")
                row.circle.backgroundColor = .systemGreen
                row.label.textColor = .label
            case .failed:
                row.circle.layer.removeAnimation(forKey: "pulse")
                row.circle.backgroundColor = .systemRed
                row.label.textColor = .label
            }
        }

        switch step {
        case .creatingAccount:
            self.subtitleLabel.text = "Создаём локальный аккаунт из файла. Не закрывайте приложение."
            style(0, state: .done)
            style(1, state: .active)
            style(2, state: .pending)
        case .connecting:
            self.subtitleLabel.text = "Обычно это занимает 5–20 секунд. Не закрывайте приложение."
            style(0, state: .done)
            style(1, state: .done)
            style(2, state: .active)
        case .ready:
            self.subtitleLabel.text = "Готово. Аккаунт подключён, чаты загружены."
            style(0, state: .done)
            style(1, state: .done)
            style(2, state: .done)
            self.doneButton.isHidden = false
            self.doneButton.setTitle("Открыть чаты", for: .normal)
            UIAccessibility.post(notification: .announcement, argument: "Аккаунт подключён")
        case .settingsOnly:
            self.subtitleLabel.text = "В файле нет ключей сессии. Настройки SyncGram восстановлены, но для входа нужен код из Telegram."
            style(0, state: .done)
            style(1, state: .done)
            style(2, state: .pending)
            self.doneButton.isHidden = false
            self.doneButton.setTitle("Понятно", for: .normal)
        case .invalidFile:
            self.subtitleLabel.text = "Ключи сессии в файле повреждены. Выберите другой файл или войдите по коду из Telegram."
            style(0, state: .failed)
            style(1, state: .failed)
            style(2, state: .pending)
            self.doneButton.isHidden = false
            self.doneButton.setTitle("Закрыть", for: .normal)
        case let .failed(message):
            self.subtitleLabel.text = message
            style(0, state: .done)
            style(1, state: .done)
            style(2, state: .active)
            self.doneButton.isHidden = false
            self.doneButton.setTitle("Понятно", for: .normal)
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    private enum StepState {
        case pending
        case active
        case done
        case failed
    }

    @objc private func donePressed() {
        self.dismiss(animated: true, completion: { [weak self] in
            self?.onClose?()
        })
    }
}