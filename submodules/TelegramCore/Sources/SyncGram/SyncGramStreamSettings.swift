import Foundation

public final class SyncGramStreamSettings {
    public static let shared = SyncGramStreamSettings()

    private let defaults = UserDefaults.standard
    private let key = "syncgram.stream.selectedPeers"

    private init() {
    }

    private func token(accountId: AccountRecordId, peerId: EnginePeer.Id) -> String {
        return "\(accountId.int64):\(peerId.toInt64())"
    }

    public func isSelected(accountId: AccountRecordId, peerId: EnginePeer.Id) -> Bool {
        let values = self.defaults.stringArray(forKey: self.key) ?? []
        return values.contains(self.token(accountId: accountId, peerId: peerId))
    }

    public func setSelected(_ selected: Bool, accountId: AccountRecordId, peerId: EnginePeer.Id) {
        var values = Set(self.defaults.stringArray(forKey: self.key) ?? [])
        let token = self.token(accountId: accountId, peerId: peerId)
        if selected {
            values.insert(token)
        } else {
            values.remove(token)
        }
        self.defaults.set(Array(values), forKey: self.key)
    }

    public var hasSelection: Bool {
        return !(self.defaults.stringArray(forKey: self.key) ?? []).isEmpty
    }

    public func clear() {
        self.defaults.removeObject(forKey: self.key)
    }
}