import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore

/// Progress of a session import, shared by the settings screen and the login screen so both show
/// exactly the same flow and never fall back to "close and reopen the app".
public enum SyncGramAccountTransferStep: Equatable {
    /// The account record is being created from the auth keys in the file.
    case creatingAccount
    /// The record exists and the app is waiting for the account to come online.
    case connecting
    /// The account is online and the chats are being loaded.
    case ready
    /// The file had no auth keys; only SyncGram settings were restored.
    case settingsOnly
    /// The auth key block in the file is malformed.
    case invalidFile
    /// Something else went wrong; the associated value is already user-facing.
    case failed(String)
}

/// Single entry point for importing a SyncGram session file. Both the settings screen and the
/// login screen used to duplicate the account-creation, switch and recovery logic; keeping it in
/// one place is what makes the flow consistent and testable.
public final class SyncGramImportedAccountCoordinator {
    private var disposable: Disposable?
    private var watchDisposable: Disposable?

    public init() {
    }

    deinit {
        self.disposable?.dispose()
        self.watchDisposable?.dispose()
    }

    public func start(snapshot: SyncGramSessionSnapshot, sharedContext: SharedAccountContext, progress: @escaping (SyncGramAccountTransferStep) -> Void) {
        assert(Queue.mainQueue().isCurrent())
        self.disposable?.dispose()
        self.watchDisposable?.dispose()

        progress(.creatingAccount)

        self.disposable = (syncGramImportSession(snapshot: snapshot, accountManager: sharedContext.accountManager)
        |> deliverOnMainQueue).start(next: { [weak self] result in
            guard let self else {
                return
            }
            switch result {
            case let .created(accountId), let .existing(accountId):
                sharedContext.markAccountAsImported(accountId)
                progress(.connecting)
                sharedContext.switchToAccount(id: accountId, fromSettingsController: nil, withChatListController: nil)
                self.watchAccount(accountId: accountId, sharedContext: sharedContext, progress: progress)
            case .missingBackupData:
                progress(.settingsOnly)
            case .invalidBackupData:
                progress(.invalidFile)
            }
        })
    }

    private func watchAccount(accountId: AccountRecordId, sharedContext: SharedAccountContext, progress: @escaping (SyncGramAccountTransferStep) -> Void) {
        let contextSignal = sharedContext.activeAccountContexts
        |> map { primary, accounts, _ -> AccountContext? in
            if let entry = accounts.first(where: { $0.0 == accountId }) {
                return entry.1
            }
            if let primary, primary.account.id == accountId {
                return primary
            }
            return nil
        }
        |> filter { $0 != nil }
        |> take(1)

        self.watchDisposable = (contextSignal
        |> mapToSignal { context -> Signal<Bool, NoError> in
            guard let context else {
                return .single(false)
            }
            let online = context.account.network.connectionStatus
            |> map { status -> Bool in
                if case .online = status {
                    return true
                }
                return false
            }
            |> filter { $0 }
            |> take(1)
            |> timeout(45.0, queue: .mainQueue(), alternate: .single(false))
            return online
        }
        |> timeout(50.0, queue: .mainQueue(), alternate: .single(false))
        |> deliverOnMainQueue).start(next: { isOnline in
            if isOnline {
                progress(.ready)
            } else {
                // The account is already added and the first sync is queued behind the network.
                // Do not ask for a restart: tell the user the truth and let the app continue.
                progress(.failed("Аккаунт добавлен. Как только появится сеть, чаты загрузятся автоматически — ничего перезапускать не нужно."))
            }
        })
    }

    public func cancel() {
        self.disposable?.dispose()
        self.disposable = nil
        self.watchDisposable?.dispose()
        self.watchDisposable = nil
    }
}