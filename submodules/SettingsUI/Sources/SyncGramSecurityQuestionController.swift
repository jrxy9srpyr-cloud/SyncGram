import Foundation
import UIKit
import Display
import TelegramCore
import TelegramPresentationData
import AccountContext

public final class SyncGramSecurityQuestionController: UIViewController {
    private let context: AccountContext
    private let presentationData: PresentationData

    private let titleLabel: UILabel
    private let descriptionLabel: UILabel
    private let questionField: UITextField
    private let answerField: UITextField
    private let presetButton: UIButton
    private let saveButton: UIButton
    private let resetButton: UIButton
    private let statusLabel: UILabel

    private let presets = [
        "Кличка первого питомца",
        "Город рождения",
        "Любимое блюдо",
        "Имя лучшего друга",
        "Марка первого автомобиля"
    ]

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.titleLabel = UILabel()
        self.descriptionLabel = UILabel()
        self.questionField = UITextField()
        self.answerField = UITextField()
        self.presetButton = UIButton(type: .system)
        self.saveButton = UIButton(type: .system)
        self.resetButton = UIButton(type: .system)
        self.statusLabel = UILabel()

        super.init(nibName: nil, bundle: nil)
        self.title = "Контрольный вопрос"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        let theme = self.presentationData.theme
        self.view.backgroundColor = theme.list.plainBackgroundColor

        self.titleLabel.text = "Контрольный вопрос"
        self.titleLabel.font = Font.semibold(20.0)
        self.titleLabel.textColor = theme.list.itemPrimaryTextColor
        self.view.addSubview(self.titleLabel)

        self.descriptionLabel.text = "Если Face ID или пароль недоступны, блокировку чатов можно снять ответом на контрольный вопрос."
        self.descriptionLabel.font = Font.regular(14.0)
        self.descriptionLabel.textColor = theme.list.itemSecondaryTextColor
        self.descriptionLabel.numberOfLines = 0
        self.view.addSubview(self.descriptionLabel)

        for field in [self.questionField, self.answerField] {
            field.font = Font.regular(16.0)
            field.textColor = theme.list.itemPrimaryTextColor
            field.backgroundColor = theme.list.itemBlocksBackgroundColor
            field.layer.cornerRadius = 10.0
            field.leftView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 12.0, height: 1.0))
            field.leftViewMode = .always
            self.view.addSubview(field)
        }
        self.questionField.placeholder = "Вопрос"
        self.answerField.placeholder = "Ответ"
        self.answerField.isSecureTextEntry = true
        if let question = SyncGramChatLock.shared.securityQuestion {
            self.questionField.text = question
        }

        self.presetButton.setTitle("Выбрать из списка", for: .normal)
        self.presetButton.setTitleColor(theme.list.itemAccentColor, for: .normal)
        self.presetButton.addTarget(self, action: #selector(self.presetTapped), for: .touchUpInside)
        self.view.addSubview(self.presetButton)

        self.saveButton.setTitle("Сохранить вопрос и ответ", for: .normal)
        self.saveButton.setTitleColor(theme.list.itemAccentColor, for: .normal)
        self.saveButton.titleLabel?.font = Font.semibold(16.0)
        self.saveButton.addTarget(self, action: #selector(self.saveTapped), for: .touchUpInside)
        self.view.addSubview(self.saveButton)

        self.resetButton.setTitle("Сбросить все блокировки", for: .normal)
        self.resetButton.setTitleColor(theme.list.itemDestructiveColor, for: .normal)
        self.resetButton.titleLabel?.font = Font.semibold(16.0)
        self.resetButton.addTarget(self, action: #selector(self.resetTapped), for: .touchUpInside)
        self.view.addSubview(self.resetButton)

        self.statusLabel.font = Font.regular(14.0)
        self.statusLabel.textColor = theme.list.itemSecondaryTextColor
        self.statusLabel.numberOfLines = 0
        self.view.addSubview(self.statusLabel)
    }

    @objc private func presetTapped() {
        let sheet = UIAlertController(title: "Контрольный вопрос", message: nil, preferredStyle: .actionSheet)
        for preset in self.presets {
            sheet.addAction(UIAlertAction(title: preset, style: .default, handler: { [weak self] _ in
                self?.questionField.text = preset
            }))
        }
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = self.presetButton
            popover.sourceRect = self.presetButton.bounds
        }
        self.present(sheet, animated: true, completion: nil)
    }

    @objc private func saveTapped() {
        let question = self.questionField.text ?? ""
        let answer = self.answerField.text ?? ""
        if question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.statusLabel.text = "Заполни вопрос и ответ."
            return
        }
        SyncGramChatLock.shared.setSecurityQuestion(question, answer: answer)
        self.answerField.text = ""
        self.statusLabel.text = "Сохранено. Ответ хранится только на этом устройстве в виде хеша."
    }

    @objc private func resetTapped() {
        let answer = self.answerField.text ?? ""
        guard SyncGramChatLock.shared.hasSecurityQuestion else {
            self.statusLabel.text = "Сначала задай контрольный вопрос и ответ."
            return
        }
        if SyncGramChatLock.shared.verifySecurityAnswer(answer) {
            SyncGramChatLock.shared.clearAllLocks()
            self.statusLabel.text = "Все блокировки сняты."
        } else {
            self.statusLabel.text = "Неверный ответ."
        }
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let bounds = self.view.bounds
        let insets = self.view.safeAreaInsets
        let width = bounds.width - 40.0
        var y = insets.top + 16.0

        self.titleLabel.frame = CGRect(x: 20.0, y: y, width: width, height: 28.0)
        y += 34.0
        self.descriptionLabel.frame = CGRect(x: 20.0, y: y, width: width, height: 58.0)
        y += 70.0
        self.questionField.frame = CGRect(x: 20.0, y: y, width: width, height: 44.0)
        y += 52.0
        self.answerField.frame = CGRect(x: 20.0, y: y, width: width, height: 44.0)
        y += 44.0
        self.presetButton.frame = CGRect(x: 20.0, y: y, width: width, height: 32.0)
        y += 40.0
        self.saveButton.frame = CGRect(x: 20.0, y: y, width: width, height: 40.0)
        y += 48.0
        self.resetButton.frame = CGRect(x: 20.0, y: y, width: width, height: 40.0)
        y += 48.0
        self.statusLabel.frame = CGRect(x: 20.0, y: y, width: width, height: 60.0)
    }
}