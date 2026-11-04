import Foundation
import LocalAuthentication
import CryptoKit
import Postbox

public final class SyncGramChatLock {
    public static let shared = SyncGramChatLock()

    private enum Key {
        static let lockedPeerIds = "syncgram.chatLock.ids"
        static let securityQuestion = "syncgram.chatLock.question"
        static let securityAnswerHash = "syncgram.chatLock.answerHash"
        static let securityAnswerSalt = "syncgram.chatLock.answerSalt"
    }

    private let defaults = UserDefaults.standard
    private var unlockedPeerIds: Set<Int64> = []

    private init() {
    }

    private var lockedPeerIds: Set<Int64> {
        get {
            let values = self.defaults.array(forKey: Key.lockedPeerIds) as? [NSNumber] ?? []
            return Set(values.map { $0.int64Value })
        }
        set {
            self.defaults.set(newValue.map { NSNumber(value: $0) }, forKey: Key.lockedPeerIds)
        }
    }

    public func isLocked(_ peerId: PeerId) -> Bool {
        return self.lockedPeerIds.contains(peerId.toInt64())
    }

    public func setLocked(_ peerId: PeerId, locked: Bool) {
        var ids = self.lockedPeerIds
        if locked {
            ids.insert(peerId.toInt64())
        } else {
            ids.remove(peerId.toInt64())
            self.unlockedPeerIds.remove(peerId.toInt64())
        }
        self.lockedPeerIds = ids
    }

    public func isUnlocked(_ peerId: PeerId) -> Bool {
        return self.unlockedPeerIds.contains(peerId.toInt64())
    }

    public func markUnlocked(_ peerId: PeerId) {
        self.unlockedPeerIds.insert(peerId.toInt64())
    }

    public func lockAgain(_ peerId: PeerId) {
        self.unlockedPeerIds.remove(peerId.toInt64())
    }

    public var securityQuestion: String? {
        let value = self.defaults.string(forKey: Key.securityQuestion)
        if let value, !value.isEmpty {
            return value
        }
        return nil
    }

    public var hasSecurityQuestion: Bool {
        return self.securityQuestion != nil && self.defaults.string(forKey: Key.securityAnswerHash) != nil
    }

    public func setSecurityQuestion(_ question: String, answer: String) {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let salt = UUID().uuidString
        self.defaults.set(trimmedQuestion, forKey: Key.securityQuestion)
        self.defaults.set(salt, forKey: Key.securityAnswerSalt)
        self.defaults.set(SyncGramChatLock.hash(trimmedAnswer, salt: salt), forKey: Key.securityAnswerHash)
    }

    public func verifySecurityAnswer(_ answer: String) -> Bool {
        guard let stored = self.defaults.string(forKey: Key.securityAnswerHash) else {
            return false
        }
        let normalized = answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let salt = self.defaults.string(forKey: Key.securityAnswerSalt) {
            return SyncGramChatLock.hash(normalized, salt: salt) == stored
        }
        // Answers saved by earlier builds had no salt. Accept the old hash once and migrate.
        if SyncGramChatLock.hash(normalized, salt: "") == stored, let question = self.securityQuestion {
            self.setSecurityQuestion(question, answer: answer)
            return true
        }
        return false
    }

    public func clearAllLocks() {
        self.lockedPeerIds = []
        self.unlockedPeerIds = []
    }

    public func clearSecurityQuestion() {
        self.defaults.removeObject(forKey: Key.securityQuestion)
        self.defaults.removeObject(forKey: Key.securityAnswerHash)
        self.defaults.removeObject(forKey: Key.securityAnswerSalt)
    }

    public func authenticate(reason: String, completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        context.localizedCancelTitle = "Отмена"
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    completion(success)
                }
            }
        } else {
            completion(false)
        }
    }

    private static func hash(_ value: String, salt: String) -> String {
        let digest = SHA256.hash(data: Data((salt + value).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}