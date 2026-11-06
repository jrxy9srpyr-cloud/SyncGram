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
    private static let fileVersion = 2
    private static let kdfIdentifier = "pbkdf2-sha256-v1"
    private static let defaultIterations = 600_000
    private static let minimumIterations = 600_000
    private static let maximumIterations = 4_000_000
    private static let saltLength = 16
    private static let keyLength = 32
    private static let maximumFileSize = 8 * 1024 * 1024

    private struct Header: Codable {
        var magic: String
        var version: Int
        var question: String
        var kdf: String?
        var salt: String
        var iterations: Int
        var sealed: String
    }

    /// Binds the visible header to the ciphertext. Without it an attacker can replace the control
    /// question with a phishing prompt or downgrade the KDF parameters without touching `sealed`.
    private static func additionalAuthenticatedData(_ header: Header) -> Data {
        let value = "\(header.magic)|\(header.version)|\(header.kdf ?? "")|\(header.iterations)|\(header.salt)|\(header.question)"
        return Data(value.utf8)
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
        let header = Header(
            magic: self.magic,
            version: self.fileVersion,
            question: trimmedQuestion,
            kdf: self.kdfIdentifier,
            salt: salt.base64EncodedString(),
            iterations: self.defaultIterations,
            sealed: ""
        )
        let sealedBox = try AES.GCM.seal(payload, using: key, authenticating: self.additionalAuthenticatedData(header))
        guard let combined = sealedBox.combined else {
            throw SyncGramSessionArchiveError.malformedPayload
        }
        let finalHeader = Header(
            magic: header.magic,
            version: header.version,
            question: header.question,
            kdf: header.kdf,
            salt: header.salt,
            iterations: header.iterations,
            sealed: combined.base64EncodedString()
        )
        return try JSONEncoder().encode(finalHeader)
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
        guard salt.count == self.saltLength, combined.count >= 28 else {
            throw SyncGramSessionArchiveError.invalidFile
        }
        let key = self.deriveKey(answer: trimmedAnswer, salt: salt, iterations: header.iterations)
        let payload: Data
        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            if header.version >= 2 {
                payload = try AES.GCM.open(box, using: key, authenticating: self.additionalAuthenticatedData(header))
            } else {
                payload = try AES.GCM.open(box, using: key)
            }
        } catch {
            // GCM authentication failure means the answer is wrong (or the header/ciphertext was
            // modified).
            throw SyncGramSessionArchiveError.wrongAnswer
        }
        do {
            let snapshot = try JSONDecoder().decode(SyncGramSessionSnapshot.self, from: payload)
            return (header.question, snapshot)
        } catch {
            // The payload decrypted successfully, so the file is genuinely incompatible rather
            // than the answer being wrong.
            throw SyncGramSessionArchiveError.malformedPayload
        }
    }

    private static func header(from data: Data) throws -> Header {
        guard data.count > 0, data.count <= self.maximumFileSize else {
            throw SyncGramSessionArchiveError.invalidFile
        }
        guard let header = try? JSONDecoder().decode(Header.self, from: data) else {
            throw SyncGramSessionArchiveError.invalidFile
        }
        guard header.magic == self.magic else {
            throw SyncGramSessionArchiveError.invalidFile
        }
        guard header.version > 0, header.version <= self.fileVersion else {
            throw SyncGramSessionArchiveError.unsupportedVersion
        }
        guard header.question.count <= 512 else {
            throw SyncGramSessionArchiveError.invalidFile
        }
        if header.version >= 2 {
            guard header.kdf == self.kdfIdentifier else {
                throw SyncGramSessionArchiveError.invalidFile
            }
            guard header.iterations >= self.minimumIterations, header.iterations <= self.maximumIterations else {
                throw SyncGramSessionArchiveError.invalidFile
            }
        } else {
            guard header.iterations > 0, header.iterations <= 2_000_000 else {
                throw SyncGramSessionArchiveError.invalidFile
            }
        }
        return header
    }

    /// Answers are normalized to NFC before key derivation: the same letter typed on two
    /// keyboards may be composed differently, which used to turn a correct answer into
    /// "wrong answer".
    private static func normalizedAnswer(_ answer: String) -> String {
        return answer
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
            .lowercased()
    }

    private static func deriveKey(answer: String, salt: Data, iterations: Int) -> SymmetricKey {
        let password = Data(self.normalizedAnswer(answer).utf8)
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