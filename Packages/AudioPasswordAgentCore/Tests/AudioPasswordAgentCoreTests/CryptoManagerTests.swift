import XCTest
import CryptoKit
@testable import AudioPasswordAgentCore

final class CryptoManagerTests: XCTestCase {

    // MARK: - Salt

    func testGenerateSaltProducesCorrectLength() {
        let salt = CryptoManager.generateSalt()
        XCTAssertEqual(salt.count, CryptoManager.saltLength)
    }

    func testGenerateSaltIsUnique() {
        let s1 = CryptoManager.generateSalt()
        let s2 = CryptoManager.generateSalt()
        XCTAssertNotEqual(s1, s2)
    }

    // MARK: - Key derivation

    func testKeyDerivationIsDeterministic() throws {
        let salt = Data(repeating: 0x42, count: CryptoManager.saltLength)
        let k1 = try CryptoManager.deriveKey(password: "master", salt: salt)
        let k2 = try CryptoManager.deriveKey(password: "master", salt: salt)
        XCTAssertEqual(k1.rawBytes, k2.rawBytes)
    }

    func testKeyDerivationProducesCorrectLength() throws {
        let salt = CryptoManager.generateSalt()
        let key  = try CryptoManager.deriveKey(password: "pw", salt: salt)
        XCTAssertEqual(key.rawBytes.count, CryptoManager.keyLength)
    }

    func testDifferentPasswordsProduceDifferentKeys() throws {
        let salt = Data(repeating: 0x01, count: CryptoManager.saltLength)
        let k1 = try CryptoManager.deriveKey(password: "alpha", salt: salt)
        let k2 = try CryptoManager.deriveKey(password: "beta",  salt: salt)
        XCTAssertNotEqual(k1.rawBytes, k2.rawBytes)
    }

    func testDifferentSaltsProduceDifferentKeys() throws {
        let s1 = Data(repeating: 0x01, count: CryptoManager.saltLength)
        let s2 = Data(repeating: 0x02, count: CryptoManager.saltLength)
        let k1 = try CryptoManager.deriveKey(password: "same", salt: s1)
        let k2 = try CryptoManager.deriveKey(password: "same", salt: s2)
        XCTAssertNotEqual(k1.rawBytes, k2.rawBytes)
    }

    func testKeyDerivationHandlesUnicodePassword() throws {
        let salt = CryptoManager.generateSalt()
        XCTAssertNoThrow(try CryptoManager.deriveKey(
            password: "пароль-🇺🇦-hasło",
            salt: salt
        ))
    }

    // MARK: - Encrypt / Decrypt roundtrip

    func testEncryptDecryptRoundtrip() throws {
        let salt = CryptoManager.generateSalt()
        let key  = try CryptoManager.deriveKey(password: "master", salt: salt)

        let plaintext = "hunter2-is-not-secure"
        let token     = try CryptoManager.encrypt(plaintext, key: key)
        let decrypted = try CryptoManager.decrypt(token, key: key)

        XCTAssertEqual(plaintext, decrypted)
    }

    func testRoundtripPreservesUnicode() throws {
        let key = try CryptoManager.deriveKey(
            password: "pw",
            salt: CryptoManager.generateSalt()
        )
        let plaintext = "Слава Україні! 🇺🇦 — hasło123"
        let token     = try CryptoManager.encrypt(plaintext, key: key)
        let decrypted = try CryptoManager.decrypt(token, key: key)
        XCTAssertEqual(plaintext, decrypted)
    }

    func testTokenHasExpectedVersionByte() throws {
        let key = try CryptoManager.deriveKey(
            password: "pw",
            salt: CryptoManager.generateSalt()
        )
        let token = try CryptoManager.encrypt("x", key: key)
        XCTAssertEqual(token.first, CryptoManager.tokenVersion)
    }

    func testEachEncryptionUsesFreshNonce() throws {
        let key = try CryptoManager.deriveKey(
            password: "pw",
            salt: CryptoManager.generateSalt()
        )
        let t1 = try CryptoManager.encrypt("identical", key: key)
        let t2 = try CryptoManager.encrypt("identical", key: key)
        XCTAssertNotEqual(t1, t2, "nonces should be unique across encryptions")
    }

    // MARK: - Negative cases

    func testDecryptWithWrongKeyFails() throws {
        let salt = CryptoManager.generateSalt()
        let k1 = try CryptoManager.deriveKey(password: "right", salt: salt)
        let k2 = try CryptoManager.deriveKey(password: "wrong", salt: salt)

        let token = try CryptoManager.encrypt("secret", key: k1)
        XCTAssertThrowsError(try CryptoManager.decrypt(token, key: k2)) { error in
            XCTAssertEqual(error as? CryptoError, .decryptionFailed)
        }
    }

    func testDecryptTamperedCiphertextFails() throws {
        let key = try CryptoManager.deriveKey(
            password: "pw",
            salt: CryptoManager.generateSalt()
        )
        var token = try CryptoManager.encrypt("secret-payload", key: key)
        // Flip a bit inside the ciphertext region
        let mid = token.count / 2
        token[mid] ^= 0xFF
        XCTAssertThrowsError(try CryptoManager.decrypt(token, key: key))
    }

    func testDecryptTamperedAuthTagFails() throws {
        let key = try CryptoManager.deriveKey(
            password: "pw",
            salt: CryptoManager.generateSalt()
        )
        var token = try CryptoManager.encrypt("secret", key: key)
        token[token.count - 1] ^= 0xFF     // flip last byte of auth tag
        XCTAssertThrowsError(try CryptoManager.decrypt(token, key: key))
    }

    func testDecryptTooShortTokenFails() throws {
        let key = try CryptoManager.deriveKey(
            password: "pw",
            salt: CryptoManager.generateSalt()
        )
        let tooShort = Data([CryptoManager.tokenVersion, 0, 0, 0])
        XCTAssertThrowsError(try CryptoManager.decrypt(tooShort, key: key)) { error in
            if case .invalidToken = error as? CryptoError { return }
            XCTFail("expected .invalidToken, got \(error)")
        }
    }

    func testDecryptWrongVersionFails() throws {
        let key = try CryptoManager.deriveKey(
            password: "pw",
            salt: CryptoManager.generateSalt()
        )
        var token = try CryptoManager.encrypt("secret", key: key)
        token[token.startIndex] = 0x99     // unsupported version
        XCTAssertThrowsError(try CryptoManager.decrypt(token, key: key)) { error in
            if case .invalidToken = error as? CryptoError { return }
            XCTFail("expected .invalidToken, got \(error)")
        }
    }
}
