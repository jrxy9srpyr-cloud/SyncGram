import Foundation
import UIKit
import UniformTypeIdentifiers
import SwiftSignalKit
import Display
import TelegramCore
import Postbox
import TelegramPresentationData
import SyncGramUI
import AccountContext

/// Export and import of the portable SyncGram session backup.
///
/// Creating a file asks for a control question and its answer. The question is stored in the file
/// header, the answer is only used to derive the AES key and is never written anywhere. Importing
/// shows the stored question and only decrypts when the right answer is typed.
public final class SyncGramSessionController: ViewController, UIDocumentPickerDelegate {
    private let context: AccountContext
    private let presentationData: PresentationData

    private let scrollView: UIScrollView
    private let titleLabel: UILabel
    private let descriptionLabel: UILabel
    private let questionTitleLabel: UILabel
    private let questionField: UITextField
    private let answerTitleLabel: UILabel
    private let answerField: UITextField
    private let exportButton: UIButton
    private let importButton: UIButton
    private let statusLabel: UILabel
    private let noteLabel: UILabel

    private var exportFileURL: URL?
    private var isExportingPicker = false
    private var importWatchDisposable: Disposable?
    private var importWatchToken: Int = 0

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.scrollView = UIScrollView()
        self.titleLabel = UILabel()
        self.descriptionLabel = UILabel()
        self.questionTitleLabel = UILabel()
        self.questionField = UITextField()
        self.answerTitleLabel = UILabel()
        self.answerField = UITextField()
        self.exportButton = UIButton(type: .system)
        self.importButton = UIButton(type: .system)
        self.statusLabel = UILabel()
        self.noteLabel = UILabel()
        super.init(navigationBarPresentationData: nil)
        self.title = "Сессия аккаунта"
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        let theme = self.presentationData.theme
        self.view.backgroundColor = theme.list.plainBackgroundColor
        SyncGramShaderHost.install(on: self.view, backgroundColor: theme.list.plainBackgroundColor, isDark: theme.overallDarkAppearance, accent: theme.list.itemAccentColor)

        self.scrollView.alwaysBounceVertical = true
        self.view.addSubview(self.scrollView)

        self.titleLabel.text = "Сессия аккаунта"
        self.titleLabel.font = Font.semibold(20.0)
        self.titleLabel.textColor = theme.list.itemPrimaryTextColor
        self.scrollView.addSubview(self.titleLabel)

        self.descriptionLabel.text = "Сохраняет полную сессию аккаунта — включая ключи Telegram — и настройки SyncGram в зашифрованный файл. При импорте аккаунт входит автоматически, без кода из Telegram."
        self.descriptionLabel.font = Font.regular(14.0)
        self.descriptionLabel.textColor = theme.list.itemSecondaryTextColor
        self.descriptionLabel.numberOfLines = 0
        self.scrollView.addSubview(self.descriptionLabel)

        self.questionTitleLabel.text = "Контрольный вопрос"
        self.questionTitleLabel.font = Font.semibold(13.0)
        self.questionTitleLabel.textColor = theme.list.itemSecondaryTextColor
        self.scrollView.addSubview(self.questionTitleLabel)

        self.configureField(self.questionField, placeholder: "Например: кличка первой собаки")
        self.scrollView.addSubview(self.questionField)

        self.answerTitleLabel.text = "Ответ"
        self.answerTitleLabel.font = Font.semibold(13.0)
        self.answerTitleLabel.textColor = theme.list.itemSecondaryTextColor
        self.scrollView.addSubview(self.answerTitleLabel)

        self.configureField(self.answerField, placeholder: "Ответ, который нужно будет ввести")
        self.answerField.isSecureTextEntry = true
        self.answerField.autocapitalizationType = .none
        self.answerField.autocorrectionType = .no
        self.scrollView.addSubview(self.answerField)

        self.exportButton.setTitle("Экспортировать в файл", for: .normal)
        self.exportButton.setTitleColor(.white, for: .normal)
        self.exportButton.titleLabel?.font = Font.semibold(16.0)
        self.exportButton.backgroundColor = theme.list.itemAccentColor
        self.exportButton.layer.cornerRadius = 12.0
        self.exportButton.accessibilityLabel = "Экспортировать сессию в файл"
        self.exportButton.addTarget(self, action: #selector(self.exportTapped), for: .touchUpInside)
        self.scrollView.addSubview(self.exportButton)

        self.importButton.setTitle("Импортировать файл сессии", for: .normal)
        self.importButton.setTitleColor(theme.list.itemAccentColor, for: .normal)
        self.importButton.titleLabel?.font = Font.semibold(16.0)
        self.importButton.backgroundColor = theme.list.itemAccentColor.withAlphaComponent(0.12)
        self.importButton.layer.cornerRadius = 12.0
        self.importButton.accessibilityLabel = "Импортировать файл сессии"
        self.importButton.addTarget(self, action: #selector(self.importTapped), for: .touchUpInside)
        self.scrollView.addSubview(self.importButton)

        self.statusLabel.font = Font.regular(13.0)
        self.statusLabel.textColor = theme.list.itemSecondaryTextColor
        self.statusLabel.numberOfLines = 0
        self.scrollView.addSubview(self.statusLabel)

        self.noteLabel.text = "Шифрование: AES-256-GCM, ключ выводится из ответа через PBKDF2-HMAC-SHA256 (600 000 итераций). Сам ответ нигде не сохраняется, поэтому без него файл не расшифровать."
        self.noteLabel.font = Font.regular(12.0)
        self.noteLabel.textColor = theme.list.itemSecondaryTextColor
        self.noteLabel.numberOfLines = 0
        self.scrollView.addSubview(self.noteLabel)

        self.view.setNeedsLayout()
    }

    private func configureField(_ field: UITextField, placeholder: String) {
        let theme = self.presentationData.theme
        field.placeholder = placeholder
        field.font = Font.regular(16.0)
        field.textColor = theme.list.itemPrimaryTextColor
        field.backgroundColor = theme.list.itemBlocksBackgroundColor
        field.layer.cornerRadius = 10.0
        field.leftView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 12.0, height: 1.0))
        field.leftViewMode = .always
        field.autocapitalizationType = .sentences
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let bounds = self.view.bounds
        let insets = self.view.safeAreaInsets
        let width = bounds.width - 40.0
        self.scrollView.frame = CGRect(x: 0.0, y: 0.0, width: bounds.width, height: bounds.height)

        var y = insets.top + 16.0
        self.titleLabel.frame = CGRect(x: 20.0, y: y, width: width, height: 26.0)
        y += 32.0
        let descriptionHeight = self.descriptionLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        self.descriptionLabel.frame = CGRect(x: 20.0, y: y, width: width, height: descriptionHeight)
        y += descriptionHeight + 18.0

        self.questionTitleLabel.frame = CGRect(x: 20.0, y: y, width: width, height: 16.0)
        y += 20.0
        self.questionField.frame = CGRect(x: 20.0, y: y, width: width, height: 44.0)
        y += 54.0

        self.answerTitleLabel.frame = CGRect(x: 20.0, y: y, width: width, height: 16.0)
        y += 20.0
        self.answerField.frame = CGRect(x: 20.0, y: y, width: width, height: 44.0)
        y += 58.0

        self.exportButton.frame = CGRect(x: 20.0, y: y, width: width, height: 48.0)
        y += 60.0
        self.importButton.frame = CGRect(x: 20.0, y: y, width: width, height: 48.0)
        y += 62.0

        let statusHeight = self.statusLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        self.statusLabel.frame = CGRect(x: 20.0, y: y, width: width, height: statusHeight)
        y += statusHeight + 14.0

        let noteHeight = self.noteLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        self.noteLabel.frame = CGRect(x: 20.0, y: y, width: width, height: noteHeight)
        y += noteHeight + 24.0

        self.scrollView.contentSize = CGSize(width: bounds.width, height: max(y, bounds.height - insets.bottom))
    }

    // MARK: - Export

    @objc private func exportTapped() {
        self.view.endEditing(true)
        let question = self.questionField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let answer = self.answerField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !question.isEmpty else {
            self.presentError("Введите контрольный вопрос.")
            return
        }
        guard answer.count >= 4 else {
            self.presentError("Ответ должен быть не короче 4 символов.")
            return
        }

        self.setBusy(true)
        self.statusLabel.text = "Готовим файл…"

        let peerSignal = self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId))
        let keySignal = self.context.account.network.getAuthKeyId()
        let backupSignal = accountBackupData(postbox: self.context.account.postbox)

        let _ = (combineLatest(queue: .mainQueue(), peerSignal, keySignal, backupSignal)
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] peer, authKeyId, backupData in
            guard let self else {
                return
            }
            let title = peer?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "Аккаунт"
            let username: String?
            let phone: String?
            if case let .user(user)? = peer {
                username = user.username
                phone = user.phone
            } else {
                username = nil
                phone = nil
            }
            let snapshot = SyncGramSessionSnapshot(
                accountRecordId: self.context.account.id.int64,
                peerId: self.context.account.peerId.toInt64(),
                authKeyId: authKeyId,
                accountTitle: title,
                username: username,
                phone: phone,
                settings: SyncGramSettings.sessionSnapshot(),
                backupData: backupData
            )

            DispatchQueue.global(qos: .userInitiated).async {
                let result: Result<(Data, URL), Error>
                do {
                    let data = try SyncGramSessionArchive.encrypt(snapshot: snapshot, question: question, answer: answer)
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd-HHmm"
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent("SyncGram-Session-\(formatter.string(from: Date())).\(SyncGramSessionArchive.fileExtension)")
                    try data.write(to: url, options: .atomic)
                    result = .success((data, url))
                } catch {
                    result = .failure(error)
                }
                DispatchQueue.main.async {
                    self.finishExport(result: result, title: title)
                }
            }
        })
    }

    private func finishExport(result: Result<(Data, URL), Error>, title: String) {
        self.setBusy(false)
        switch result {
        case let .success((data, url)):
            self.exportFileURL = url
            self.statusLabel.text = "Файл создан: \(url.lastPathComponent) (\(data.count) байт). Ответ нигде не сохранён — запомните его."
            self.isExportingPicker = true
            let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
            picker.delegate = self
            self.present(picker, animated: true, completion: nil)
        case let .failure(error):
            self.statusLabel.text = nil
            self.presentError(self.message(for: error))
        }
    }

    // MARK: - Import

    @objc private func importTapped() {
        self.view.endEditing(true)
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data, .json], asCopy: true)
        picker.delegate = self
        self.present(picker, animated: true, completion: nil)
    }

    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if self.isExportingPicker {
            self.isExportingPicker = false
            return
        }
        guard let url = urls.first else {
            return
        }
        self.handlePickedFile(url)
    }

    public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        self.isExportingPicker = false
        self.setBusy(false)
    }

    private func handlePickedFile(_ url: URL) {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            self.presentError("Не удалось прочитать файл.")
            return
        }
        let question: String
        do {
            question = try SyncGramSessionArchive.question(in: data)
        } catch {
            self.presentError("Это не файл сессии SyncGram.")
            return
        }
        self.askAnswer(question: question, data: data)
    }

    private func askAnswer(question: String, data: Data) {
        let alert = UIAlertController(title: "Контрольный вопрос", message: question, preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Ответ"
            field.isSecureTextEntry = true
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Открыть", style: .default, handler: { [weak self, weak alert] _ in
            guard let self else {
                return
            }
            let answer = alert?.textFields?.first?.text ?? ""
            self.decrypt(data: data, answer: answer)
        }))
        self.present(alert, animated: true, completion: nil)
    }

    private func decrypt(data: Data, answer: String) {
        self.setBusy(true)
        self.statusLabel.text = "Расшифровываем…"
        DispatchQueue.global(qos: .userInitiated).async {
            let result: Result<(String, SyncGramSessionSnapshot), Error>
            do {
                result = .success(try SyncGramSessionArchive.decrypt(data: data, answer: answer))
            } catch {
                result = .failure(error)
            }
            DispatchQueue.main.async {
                self.setBusy(false)
                switch result {
                case let .success((question, snapshot)):
                    self.apply(snapshot: snapshot, question: question)
                case let .failure(error):
                    self.statusLabel.text = nil
                    self.presentError(self.message(for: error))
                }
            }
        }
    }

    private func apply(snapshot: SyncGramSessionSnapshot, question: String) {
        SyncGramSettings.applySessionSnapshot(snapshot.settings)
        NotificationCenter.default.post(name: SyncGramNotificationNames.settingsChanged, object: nil)
        NotificationCenter.default.post(name: SyncGramNotificationNames.chatListScaleChanged, object: nil)

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let created = formatter.string(from: Date(timeIntervalSince1970: snapshot.createdAt))
        let username = snapshot.username.map { "@\($0)" } ?? "—"

        self.answerField.text = nil
        self.questionField.text = question

        // Importing the backup of the account that is already active must not create a second
        // record for the same Telegram account: everything that matters is the settings above.
        if snapshot.peerId == self.context.account.peerId.toInt64() {
            self.statusLabel.text = "Импортировано: \(snapshot.accountTitle) (\(username)). Это текущий аккаунт — настройки SyncGram применены, повторный вход не нужен."
            SyncGramToast.show("Настройки SyncGram импортированы")
            return
        }

        let _ = (syncGramImportSession(snapshot: snapshot, accountManager: self.context.sharedContext.accountManager)
        |> deliverOnMainQueue).start(next: { [weak self] result in
            guard let self else {
                return
            }
            switch result {
            case let .created(accountId), let .existing(accountId):
                self.statusLabel.text = "Импортировано: \(snapshot.accountTitle) (\(username)). Файл создан \(created). Входим в аккаунт по сохранённой сессии…"
                SyncGramToast.show("Сессия «\(snapshot.accountTitle)» импортирована")
                self.context.sharedContext.switchToAccount(id: accountId, fromSettingsController: nil, withChatListController: nil)
                self.watchImportedAccount(id: accountId)
            case .missingBackupData:
                self.statusLabel.text = "Импортировано: \(snapshot.accountTitle) (\(username)). Файл создан \(created). В файле нет ключей сессии — восстановлены только настройки SyncGram, войдите по коду из Telegram."
                SyncGramToast.show("Настройки SyncGram импортированы")
            }
        })
    }

    // MARK: - Helpers

    /// An imported account is created inside a running app, which is not the same as loading it
    /// from disk at launch: its first `stateManager` pass can start before the network is ready and
    /// then stay in `.updating` forever (the chat list shows «Обновление…» until the app is
    /// restarted). Watch the new account, bounce the connection once if it does not come online,
    /// and as a last resort ask the user to reopen the app, which loads the account through the
    /// regular `AuthorizedAccountState` path.
    private func watchImportedAccount(id: AccountRecordId) {
        self.importWatchToken += 1
        self.waitForImportedAccountOnline(id: id, attempt: 0)
    }

    private func importedAccountContextSignal(id: AccountRecordId) -> Signal<AccountContext?, NoError> {
        return self.context.sharedContext.activeAccountContexts
        |> map { primary, accounts, _ -> AccountContext? in
            if let entry = accounts.first(where: { $0.0 == id }) {
                return entry.1
            }
            if let primary, primary.account.id == id {
                return primary
            }
            return nil
        }
        |> filter { $0 != nil }
        |> take(1)
    }

    private func waitForImportedAccountOnline(id: AccountRecordId, attempt: Int) {
        let token = self.importWatchToken
        let online = self.importedAccountContextSignal(id: id)
        |> mapToSignal { context -> Signal<Bool, NoError> in
            guard let context else {
                return .single(true)
            }
            return context.account.network.connectionStatus
            |> map { status -> Bool in
                if case .online = status {
                    return true
                }
                return false
            }
            |> filter { $0 }
            |> take(1)
        }
        |> timeout(15.0, queue: .mainQueue(), alternate: .single(false))
        |> deliverOnMainQueue

        self.importWatchDisposable = online.start(next: { [weak self] isOnline in
            guard let self, token == self.importWatchToken else {
                return
            }
            if isOnline {
                Logger.shared.log("SyncGram", "imported account \(id.int64) is online")
                self.importWatchDisposable = nil
                return
            }
            if attempt == 0 {
                Logger.shared.log("SyncGram", "imported account \(id.int64) did not come online, bouncing the connection")
                let _ = self.importedAccountContextSignal(id: id).start(next: { context in
                    guard let context else {
                        return
                    }
                    let account = context.account
                    account.shouldBeServiceTaskMaster.set(.single(.never))
                    Queue.mainQueue().after(1.5) {
                        account.shouldBeServiceTaskMaster.set(.single(.now))
                        account.resetStateManagement()
                    }
                })
                self.waitForImportedAccountOnline(id: id, attempt: 1)
            } else {
                Logger.shared.log("SyncGram", "imported account \(id.int64) is still not online, asking for a restart")
                self.presentImportRestartNotice()
            }
        })
    }

    private func presentImportRestartNotice() {
        guard self.presentedViewController == nil else {
            return
        }
        let alert = UIAlertController(title: "Аккаунт добавлен", message: "Telegram не успел подключиться к серверам в этом запуске. Закройте приложение и откройте его снова — чаты загрузятся как обычно.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Позже", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Закрыть приложение", style: .default, handler: { _ in
            exit(0)
        }))
        if let rootController = self.context.sharedContext.mainWindow?.viewController as? UIViewController {
            rootController.present(alert, animated: true, completion: nil)
        }
    }

    private func setBusy(_ busy: Bool) {
        self.exportButton.isEnabled = !busy
        self.importButton.isEnabled = !busy
        self.exportButton.alpha = busy ? 0.6 : 1.0
        self.importButton.alpha = busy ? 0.6 : 1.0
    }

    private func message(for error: Error) -> String {
        switch error {
        case SyncGramSessionArchiveError.wrongAnswer:
            return "Неверный ответ или файл повреждён. Расшифровать не удалось."
        case SyncGramSessionArchiveError.invalidFile:
            return "Это не файл сессии SyncGram."
        case SyncGramSessionArchiveError.unsupportedVersion:
            return "Файл создан более новой версией SyncGram."
        case SyncGramSessionArchiveError.emptyAnswer:
            return "Введите ответ на контрольный вопрос."
        case SyncGramSessionArchiveError.emptyQuestion:
            return "Введите контрольный вопрос."
        default:
            return "Не удалось обработать файл."
        }
    }

    private func presentError(_ text: String) {
        let alert = UIAlertController(title: "Ошибка", message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}