import XCTest
@testable import TelegramCore

final class SyncGramSessionArchiveTests: XCTestCase {
    private func makeSnapshot() -> SyncGramSessionSnapshot {
        return SyncGramSessionSnapshot(
            accountRecordId: 42,
            peerId: 777,
            authKeyId: 123456,
            accountTitle: "Иван",
            username: "ivan",
            phone: "79990000000",
            settings: ["stream": "1", "shader": "0"],
            backupData: nil
        )
    }

    private func headerDictionary(from data: Data) throws -> [String: Any] {
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testRoundTrip() throws {
        let snapshot = self.makeSnapshot()
        let data = try SyncGramSessionArchive.encrypt(snapshot: snapshot, question: "Кличка собаки", answer: "Барсик")
        let (question, decoded) = try SyncGramSessionArchive.decrypt(data: data, answer: "Барсик")
        XCTAssertEqual(question, "Кличка собаки")
        XCTAssertEqual(decoded.peerId, snapshot.peerId)
        XCTAssertEqual(decoded.accountTitle, snapshot.accountTitle)
        XCTAssertEqual(decoded.settings["stream"], "1")
    }

    func testAnswerIsCaseAndWhitespaceInsensitive() throws {
        let data = try SyncGramSessionArchive.encrypt(snapshot: self.makeSnapshot(), question: "Город", answer: "Москва")
        XCTAssertNoThrow(try SyncGramSessionArchive.decrypt(data: data, answer: "  москва  "))
    }

    func testAnswerIsUnicodeNormalized() throws {
        // NFD "ё" (е + combining diaeresis) must derive the same key as precomposed NFC "ё".
        let nfd = "е\u{0308}жик"
        let data = try SyncGramSessionArchive.encrypt(snapshot: self.makeSnapshot(), question: "Животное", answer: nfd)
        XCTAssertNoThrow(try SyncGramSessionArchive.decrypt(data: data, answer: "ёжик"))
    }

    func testWrongAnswerIsRejected() throws {
        let data = try SyncGramSessionArchive.encrypt(snapshot: self.makeSnapshot(), question: "Город", answer: "Москва")
        XCTAssertThrowsError(try SyncGramSessionArchive.decrypt(data: data, answer: "Париж")) { error in
            guard case SyncGramSessionArchiveError.wrongAnswer = error else {
                return XCTFail("expected wrongAnswer, got \(error)")
            }
        }
    }

    func testTamperedHeaderIsRejected() throws {
        let data = try SyncGramSessionArchive.encrypt(snapshot: self.makeSnapshot(), question: "Город", answer: "Москва")
        var header = try self.headerDictionary(from: data)
        header["question"] = "Введите номер карты"
        let tampered = try JSONSerialization.data(withJSONObject: header)
        XCTAssertThrowsError(try SyncGramSessionArchive.decrypt(data: tampered, answer: "Москва")) { error in
            guard case SyncGramSessionArchiveError.wrongAnswer = error else {
                return XCTFail("expected wrongAnswer, got \(error)")
            }
        }
    }

    func testTamperedIterationsIsRejected() throws {
        let data = try SyncGramSessionArchive.encrypt(snapshot: self.makeSnapshot(), question: "Город", answer: "Москва")
        var header = try self.headerDictionary(from: data)
        header["iterations"] = 1
        let tampered = try JSONSerialization.data(withJSONObject: header)
        XCTAssertThrowsError(try SyncGramSessionArchive.decrypt(data: tampered, answer: "Москва"))
    }

    func testInvalidFileIsRejected() {
        XCTAssertThrowsError(try SyncGramSessionArchive.question(in: Data("not a session".utf8))) { error in
            guard case SyncGramSessionArchiveError.invalidFile = error else {
                return XCTFail("expected invalidFile, got \(error)")
            }
        }
    }

    func testOversizedQuestionIsRejected() throws {
        let header: [String: Any] = [
            "magic": "SyncGramSessionFile",
            "version": 2,
            "question": String(repeating: "а", count: 600),
            "kdf": "pbkdf2-sha256-v1",
            "salt": Data(count: 16).base64EncodedString(),
            "iterations": 600_000,
            "sealed": Data(count: 40).base64EncodedString()
        ]
        let data = try JSONSerialization.data(withJSONObject: header)
        XCTAssertThrowsError(try SyncGramSessionArchive.question(in: data)) { error in
            guard case SyncGramSessionArchiveError.invalidFile = error else {
                return XCTFail("expected invalidFile, got \(error)")
            }
        }
    }
}