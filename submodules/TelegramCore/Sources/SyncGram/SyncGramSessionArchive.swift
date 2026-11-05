import Foundation
import CryptoKit

/// Snapshot of a full SyncGram session: account metadata, the Telegram datacenter auth keys and
/// SyncGram settings. The auth keys come from `accountBackupData(postbox:)`, the same data Telegram
/// uses for device-to-device account transfer, so importing the file signs the user back into the
/// account instead of restoring only the cosmetic settings.
public struct SyncGramSessionSnapshot: Codable {
    public var version: Int
    public var createdAt: Double
    public var accountRecordId: Int64
    public var peerId: Int64
    public var authKeyId: Int64
    public var accountTitle: String
    public var username: String?
    public var phone: String?
    public var settings: [String: String]
    public var backupData: AccountBackupData?

    public init(version: Int = 1, createdAt: Double = Date().timeIntervalSince1970, accountRecordId: Int64, peerId: Int64, authKeyId: Int64, accountTitle: String, username: String?, phone: String?, settings: [String: String], backupData: AccountBackupData? = nil) {
        self.version = version
        self.createdAt = createdAt
        self.accountRecordId = accountRecordId
        self.peerId = peerId
        self.authKeyId = authKeyId
        self.accountTitle = accountTitle
        self.username = username
        self.phone = phone
        self.settings = settings
        self.backupData = backupData
    }
}

public enum SyncGramSessionArchiveError: Error {
    case invalidFile
    case unsupportedVersion
    case emptyQuestion
    case emptyAnswer
    case wrongAnswer
    case malformedPayload
}

/// Password-based encryption for the session backup file.
///
/// The file is JSON so the control question can be read before the answer is typed:
/// `{ magic, version, question, salt, iterations, sealed }`. The payload itself is encrypted with
/// AES-256-GCM and the key is derived from the answer with PBKDF2-HMAC-SHA256. AES-GCM authenticates
/// the ciphertext, so a wrong answer fails to decrypt instead of producing garbage; the 600 000
/// PBKDF2 rounds make offline guessing of the answer expensive. The answer is never stored.
public enum SyncGramSessionArchive {
    public static let fileExtension = "syncgram"

    private static let magic = "SyncGramSessionFile"
    private static let fileVersion = 1
    private static let defaultIterations = 600_000
    private static let saltLength = 16
    private static let keyLength = 32

    private struct Header: Codable {
        var magic: String
        var version: Int
        var question: String
        var salt: String
        var iterations: Int
        var sealed: String
    }

    public static func question(in data: Data) throws -> String {
        return try self.header(from: data).question
    }

    public static func encrypt(snapshot: SyncGramSessionSnapshot, question: String, answer: String) throws -> Data {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else {
            throw SyncGramSessionArchiveError.emptyQuestion
        }
        guard !trimmedAnswer.isEmpty else {
            throw SyncGramSessionArchiveError.emptyAnswer
        }

        let payload = try JSONEncoder().encode(snapshot)
        // `UInt8.random(in:)` draws from the system CSPRNG, so the salt is unpredictable.
        let salt = Data((0 ..< self.saltLength).map { _ in UInt8.random(in: 0 ... 255) })

        let key = self.deriveKey(answer: trimmedAnswer, salt: salt, iterations: self.defaultIterations)
        let sealedBox = try AES.GCM.seal(payload, using: key)
        guard let combined = sealedBox.combined else {
            throw SyncGramSessionArchiveError.malformedPayload
        }

        let header = Header(
            magic: self.magic,
            version: self.fileVersion,
            question: trimmedQuestion,
            salt: salt.base64EncodedString(),
            iterations: self.defaultIterations,
            sealed: combined.base64EncodedString()
        )
        return try JSONEncoder().encode(header)
    }

    public static func decrypt(data: Data, answer: String) throws -> (question: String, snapshot: SyncGramSessionSnapshot) {
        let header = try self.header(from: data)
        let trimmedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAnswer.isEmpty else {
            throw SyncGramSessionArchiveError.emptyAnswer
        }
        guard let salt = Data(base64Encoded: header.salt), let combined = Data(base64Encoded: header.sealed) else {
            throw SyncGramSessionArchiveError.invalidFile
        }
        let key = self.deriveKey(answer: trimmedAnswer, salt: salt, iterations: header.iterations)
        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            let payload = try AES.GCM.open(box, using: key)
            let snapshot = try JSONDecoder().decode(SyncGramSessionSnapshot.self, from: payload)
            return (header.question, snapshot)
        } catch {
            // GCM authentication failure means the answer is wrong (or the file was modified).
            throw SyncGramSessionArchiveError.wrongAnswer
        }
    }

    private static func header(from data: Data) throws -> Header {
        guard let header = try? JSONDecoder().decode(Header.self, from: data) else {
            throw SyncGramSessionArchiveError.invalidFile
        }
        guard header.magic == self.magic else {
            throw SyncGramSessionArchiveError.invalidFile
        }
        guard header.version <= self.fileVersion else {
            throw SyncGramSessionArchiveError.unsupportedVersion
        }
        guard header.iterations > 0, header.iterations <= 2_000_000 else {
            throw SyncGramSessionArchiveError.invalidFile
        }
        return header
    }

    private static func deriveKey(answer: String, salt: Data, iterations: Int) -> SymmetricKey {
        let password = Data(answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().utf8)
        let derived = self.pbkdf2(password: password, salt: salt, iterations: iterations, keyLength: self.keyLength)
        return SymmetricKey(data: derived)
    }

    /// PBKDF2-HMAC-SHA256 implemented on top of CryptoKit, so no extra C shim is required.
    private static func pbkdf2(password: Data, salt: Data, iterations: Int, keyLength: Int) -> Data {
        var derived = Data()
        var blockIndex: UInt32 = 1
        let baseKey = SymmetricKey(data: password)

        while derived.count < keyLength {
            var block = salt
            var index = blockIndex.bigEndian
            withUnsafeBytes(of: &index) { raw in
                block.append(contentsOf: raw)
            }

            var u = Data(HMAC<SHA256>.authenticationCode(for: block, using: baseKey))
            var accumulator = u
            var round = 1
            while round < iterations {
                u = Data(HMAC<SHA256>.authenticationCode(for: u, using: baseKey))
                for position in 0 ..< accumulator.count {
                    accumulator[position] ^= u[position]
                }
                round += 1
            }
            derived.append(accumulator)
            blockIndex += 1
        }

        return derived.prefix(keyLength)
    }
}