import Foundation
import Postbox
import SwiftSignalKit

public enum SyncGramSessionImportResult {
    /// A brand-new account record was created from the auth keys inside the file.
    case created(AccountRecordId)
    /// The same Telegram account is already present on this device; only its settings are applied.
    case existing(AccountRecordId)
    /// The file was produced by a build that stored settings only (no auth keys).
    case missingBackupData
}

/// Creates a real local account record from the datacenter auth keys stored in an imported session
/// file. `SharedAccountContext` observes the account manager records and picks the new record up,
/// calls `accountWithId(..., backupData:)`, restores the authorized state and returns a logged-in
/// account. This is the same mechanism Telegram itself uses for device-to-device account transfer.
public func syncGramImportSession(snapshot: SyncGramSessionSnapshot, accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<SyncGramSessionImportResult, NoError> {
    return accountManager.transaction { transaction -> SyncGramSessionImportResult in
        guard let backupData = snapshot.backupData else {
            return .missingBackupData
        }

        for record in transaction.getRecords() {
            for attribute in record.attributes {
                if case let .backupData(value) = attribute, value.data?.peerId == snapshot.peerId {
                    return .existing(record.id)
                }
            }
        }

        var maxOrder: Int32 = 0
        for record in transaction.getRecords() {
            for attribute in record.attributes {
                if case let .sortOrder(value) = attribute {
                    maxOrder = max(maxOrder, value.order)
                }
            }
        }

        let attributes: [TelegramAccountManagerTypes.Attribute] = [
            .environment(AccountEnvironmentAttribute(environment: .production)),
            .sortOrder(AccountSortOrderAttribute(order: maxOrder + 1)),
            .backupData(AccountBackupDataAttribute(data: backupData))
        ]
        let id = transaction.createRecord(attributes)
        return .created(id)
    }
}