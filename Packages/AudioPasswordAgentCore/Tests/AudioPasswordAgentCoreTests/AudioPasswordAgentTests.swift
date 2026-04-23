import XCTest
@testable import AudioPasswordAgentCore

final class AudioPasswordAgentTests: XCTestCase {

    var tempDir:   URL!
    var vaultDir:  URL!
    var sourceWAV: URL!

    override func setUpWithError() throws {
        tempDir  = FileManager.default.temporaryDirectory
            .appendingPathComponent("APA-agent-\(UUID().uuidString)")
        vaultDir = tempDir.appendingPathComponent("vault")
        try FileManager.default.createDirectory(
            at: tempDir, withIntermediateDirectories: true
        )
        // Write a carrier WAV (large enough for all test payloads)
        sourceWAV = tempDir.appendingPathComponent("carrier.wav")
        try TestWAVFactory.silence(samples: 44_100).write(to: sourceWAV) // 1 s @ 44.1 kHz
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Init / vault creation

    func testInitCreatesVaultConfig() throws {
        _ = try AudioPasswordAgent(masterPassword: "pw", vaultDirectory: vaultDir)
        let configURL = vaultDir.appendingPathComponent("vault.config")
        XCTAssertTrue(FileManager.default.fileExists(atPath: configURL.path))
    }

    func testReinitWithSamePasswordSucceeds() throws {
        let output = vaultDir.appendingPathComponent("out.wav")
        let agent1 = try AudioPasswordAgent(masterPassword: "pw", vaultDirectory: vaultDir)
        try agent1.storeCredential(
            service: "GitHub", username: "me", password: "s3cret",
            intoAudioAt: sourceWAV, writingTo: output
        )
        // Re-open vault with same password
        let agent2 = try AudioPasswordAgent(masterPassword: "pw", vaultDirectory: vaultDir)
        let cred = try agent2.retrieveCredential(fromAudioAt: output)
        XCTAssertEqual(cred.password, "s3cret")
    }

    // MARK: - Store / retrieve roundtrip

    func testStoreAndRetrieveRoundtrip() throws {
        let output = vaultDir.appendingPathComponent("out.wav")
        let agent  = try AudioPasswordAgent(masterPassword: "master123", vaultDirectory: vaultDir)

        try agent.storeCredential(
            service: "GitHub", username: "dev@example.com", password: "hunter2",
            intoAudioAt: sourceWAV, writingTo: output
        )

        let cred = try agent.retrieveCredential(fromAudioAt: output)
        XCTAssertEqual(cred.service,  "GitHub")
        XCTAssertEqual(cred.username, "dev@example.com")
        XCTAssertEqual(cred.password, "hunter2")
    }

    func testRoundtripPreservesMetadata() throws {
        let output = vaultDir.appendingPathComponent("out.wav")
        let agent  = try AudioPasswordAgent(masterPassword: "pw", vaultDirectory: vaultDir)
        let meta   = ["url": "github.com", "2fa": "true"]

        try agent.storeCredential(
            service: "GitHub", username: "me", password: "pw",
            intoAudioAt: sourceWAV, writingTo: output, metadata: meta
        )

        let cred = try agent.retrieveCredential(fromAudioAt: output)
        XCTAssertEqual(cred.metadata, meta)
    }

    func testRoundtripPreservesUnicodePassword() throws {
        let output   = vaultDir.appendingPathComponent("out.wav")
        let agent    = try AudioPasswordAgent(masterPassword: "pw", vaultDirectory: vaultDir)
        let password = "Пароль-🇺🇦-hasło-123"

        try agent.storeCredential(
            service: "Test", username: "u", password: password,
            intoAudioAt: sourceWAV, writingTo: output
        )
        let cred = try agent.retrieveCredential(fromAudioAt: output)
        XCTAssertEqual(cred.password, password)
    }

    func testStoreReturnsCorrectInfo() throws {
        let output = vaultDir.appendingPathComponent("out.wav")
        let agent  = try AudioPasswordAgent(masterPassword: "pw", vaultDirectory: vaultDir)

        let info = try agent.storeCredential(
            service: "Notion", username: "me@example.com", password: "pw",
            intoAudioAt: sourceWAV, writingTo: output
        )
        XCTAssertEqual(info.service,   "Notion")
        XCTAssertEqual(info.username,  "me@example.com")
        XCTAssertEqual(info.audioFile, output)
    }

    func testSourceFileUnchangedAfterStore() throws {
        let original = try Data(contentsOf: sourceWAV)
        let output   = vaultDir.appendingPathComponent("out.wav")
        let agent    = try AudioPasswordAgent(masterPassword: "pw", vaultDirectory: vaultDir)

        try agent.storeCredential(
            service: "X", username: "u", password: "p",
            intoAudioAt: sourceWAV, writingTo: output
        )
        XCTAssertEqual(try Data(contentsOf: sourceWAV), original)
    }

    // MARK: - Wrong password

    func testRetrieveWithWrongMasterPasswordThrows() throws {
        let output = vaultDir.appendingPathComponent("out.wav")
        let agent1 = try AudioPasswordAgent(masterPassword: "correct", vaultDirectory: vaultDir)
        try agent1.storeCredential(
            service: "X", username: "u", password: "secret",
            intoAudioAt: sourceWAV, writingTo: output
        )

        // New vault dir → fresh salt → completely different key
        let altVaultDir = tempDir.appendingPathComponent("alt-vault")
        let agent2 = try AudioPasswordAgent(masterPassword: "wrong", vaultDirectory: altVaultDir)
        XCTAssertThrowsError(try agent2.retrieveCredential(fromAudioAt: output)) { err in
            XCTAssertEqual(err as? VaultError, .wrongMasterPassword)
        }
    }

    // MARK: - Extract from plain carrier

    func testRetrieveFromPristineWAVThrows() throws {
        let agent = try AudioPasswordAgent(masterPassword: "pw", vaultDirectory: vaultDir)
        XCTAssertThrowsError(try agent.retrieveCredential(fromAudioAt: sourceWAV))
    }

    // MARK: - Listing

    func testListCredentialsReturnsAllStoredServices() throws {
        let agent = try AudioPasswordAgent(masterPassword: "pw", vaultDirectory: vaultDir)

        for (i, service) in ["GitHub", "Gmail", "Notion"].enumerated() {
            let wav = try makeCopy(of: sourceWAV, name: "carrier\(i).wav")
            let out = vaultDir.appendingPathComponent("\(service.lowercased()).wav")
            try agent.storeCredential(
                service: service, username: "u", password: "p",
                intoAudioAt: wav, writingTo: out
            )
        }

        let list = try agent.listCredentials(inDirectory: vaultDir)
        let names = list.map(\.service).sorted()
        XCTAssertEqual(names, ["GitHub", "Gmail", "Notion"])
    }

    func testListSkipsCarrierWAVsWithNoPayload() throws {
        let agent = try AudioPasswordAgent(masterPassword: "pw", vaultDirectory: vaultDir)

        // One credential WAV
        let out = vaultDir.appendingPathComponent("github.wav")
        try agent.storeCredential(
            service: "GitHub", username: "u", password: "p",
            intoAudioAt: sourceWAV, writingTo: out
        )
        // One plain carrier WAV
        let plain = vaultDir.appendingPathComponent("plain.wav")
        try TestWAVFactory.silence(samples: 44_100).write(to: plain)

        let list = try agent.listCredentials(inDirectory: vaultDir)
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list.first?.service, "GitHub")
    }

    func testListIsSortedByServiceName() throws {
        let agent = try AudioPasswordAgent(masterPassword: "pw", vaultDirectory: vaultDir)

        for (i, service) in ["Notion", "AWS", "Gmail"].enumerated() {
            let wav = try makeCopy(of: sourceWAV, name: "c\(i).wav")
            let out = vaultDir.appendingPathComponent("\(i).wav")
            try agent.storeCredential(
                service: service, username: "u", password: "p",
                intoAudioAt: wav, writingTo: out
            )
        }

        let names = try agent.listCredentials(inDirectory: vaultDir).map(\.service)
        XCTAssertEqual(names, ["AWS", "Gmail", "Notion"])
    }

    // MARK: - Helpers

    private func makeCopy(of url: URL, name: String) throws -> URL {
        let copy = tempDir.appendingPathComponent(name)
        try FileManager.default.copyItem(at: url, to: copy)
        return copy
    }
}
