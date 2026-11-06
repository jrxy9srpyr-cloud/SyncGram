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
        self.setSelected(selected, accountId: accountId, peerId: peerId, notify: true)
    }

    /// Batch-friendly variant used when "select all" changes many peers at once: notify once at
    /// the end instead of restarting the stream pipeline for every chat.
    public func setSelected(_ selected: Bool, accountId: AccountRecordId, peerId: EnginePeer.Id, notify: Bool) {
        var values = Set(self.defaults.stringArray(forKey: self.key) ?? [])
        let token = self.token(accountId: accountId, peerId: peerId)
        if selected {
            values.insert(token)
        } else {
            values.remove(token)
        }
        self.defaults.set(Array(values), forKey: self.key)
        if notify {
            self.notifySelectionChanged()
        }
    }

    public func notifySelectionChanged() {
        NotificationCenter.default.post(name: SyncGramNotificationNames.streamSelectionChanged, object: nil)
    }

    public var hasSelection: Bool {
        return !(self.defaults.stringArray(forKey: self.key) ?? []).isEmpty
    }

    /// Peer ids selected for the stream on the given account. The token is `accountId:peerId`.
    public func selectedPeerIds(accountId: AccountRecordId) -> [EnginePeer.Id] {
        let prefix = "\(accountId.int64):"
        let values = self.defaults.stringArray(forKey: self.key) ?? []
        return values.compactMap { value -> EnginePeer.Id? in
            guard value.hasPrefix(prefix) else {
                return nil
            }
            guard let raw = Int64(value.dropFirst(prefix.count)) else {
                return nil
            }
            return EnginePeer.Id(raw)
        }
    }

    public func clear() {
        self.defaults.removeObject(forKey: self.key)
        self.notifySelectionChanged()
    }
}