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
    /// The auth key block is malformed (wrong length, impossible datacenter id, mismatched peer).
    case invalidBackupData
}

/// Creates a real local account record from the datacenter auth keys stored in an imported session
/// file. `SharedAccountContext` observes the account manager records and picks the new record up,
/// calls `accountWithId(..., backupData:)`, restores the authorized state and returns a logged-in
/// account. This is the same mechanism Telegram itself uses for device-to-device account transfer.
public func syncGramImportSession(snapshot: SyncGramSessionSnapshot, accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<SyncGramSessionImportResult, NoError> {
    var validationError = false
    if let backupData = snapshot.backupData {
        if !isValidBackupData(backupData, expectedPeerId: snapshot.peerId) {
            validationError = true
        }
    }

    return accountManager.transaction { transaction -> SyncGramSessionImportResult in
        guard let backupData = snapshot.backupData else {
            return .missingBackupData
        }
        if validationError {
            return .invalidBackupData
        }

        for record in transaction.getRecords() {
            var matches = false
            var isLoggedOut = false
            for attribute in record.attributes {
                switch attribute {
                case let .backupData(value):
                    if value.data?.peerId == snapshot.peerId {
                        matches = true
                    }
                case let .peerIdentity(value):
                    if value.peerId == snapshot.peerId {
                        matches = true
                    }
                case .loggedOut:
                    isLoggedOut = true
                default:
                    break
                }
            }
            if !matches {
                continue
            }
            if isLoggedOut {
                // The local session was revoked (logged out or terminated from another device).
                // Re-import the same record instead of creating a duplicate for the same peer.
                transaction.updateRecord(record.id, { current in
                    guard let current = current else {
                        return nil
                    }
                    var attributes = current.attributes.filter { attribute in
                        switch attribute {
                        case .loggedOut, .backupData, .peerIdentity:
                            return false
                        default:
                            return true
                        }
                    }
                    attributes.append(.backupData(AccountBackupDataAttribute(data: backupData)))
                    return AccountRecord(id: current.id, attributes: attributes, temporarySessionId: current.temporarySessionId)
                })
            }
            // The account is already here. Make it current in the same transaction so the
            // account manager can switch to it even before the caller's `switchToAccount`.
            transaction.setCurrentId(record.id)
            transaction.removeAuth()
            return .existing(record.id)
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
        // Set the imported account as current inside the same transaction as `createRecord`. This
        // way the account manager's records view already knows the primary id when it first picks
        // up the new record, and the account is switched to as soon as it finishes loading.
        transaction.setCurrentId(id)
        // An import usually happens from the login screen, where an unauthorized account is
        // current; drop it so the app does not stay on the authorization screen.
        transaction.removeAuth()
        return .created(id)
    }
}

/// The backup block goes straight into `MTDatacenterAuthInfo` on the restore path, which force
/// unwraps its inputs. Validate before a record is created so a hand-edited or truncated file
/// cannot crash the app.
private func isValidBackupData(_ backupData: AccountBackupData, expectedPeerId: Int64) -> Bool {
    guard backupData.peerId > 0, backupData.peerId == expectedPeerId else {
        return false
    }
    guard (1 ... 10).contains(backupData.masterDatacenterId) else {
        return false
    }
    guard backupData.masterDatacenterKey.count == 256 else {
        return false
    }
    guard backupData.additionalDatacenterKeys.count <= 10 else {
        return false
    }
    for (id, key) in backupData.additionalDatacenterKeys {
        guard (1 ... 10).contains(id), key.key.count == 256, key.keyId != 0 else {
            return false
        }
    }
    return true
}