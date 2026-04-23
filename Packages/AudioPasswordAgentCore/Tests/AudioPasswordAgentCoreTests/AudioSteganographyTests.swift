import XCTest
@testable import AudioPasswordAgentCore

final class AudioSteganographyTests: XCTestCase {

    var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("APA-audio-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDir, withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Validation

    func testValidateAcceptsValidWAV() throws {
        let url = try writeWAV(TestWAVFactory.silence(samples: 10_000))
        XCTAssertNoThrow(try AudioSteganography.validate(audioAt: url))
    }

    func testValidateRejectsNonExistentFile() {
        let url = tempDir.appendingPathComponent("missing.wav")
        XCTAssertThrowsError(try AudioSteganography.validate(audioAt: url)) { err in
            guard case .fileNotFound = err as? AudioError else {
                return XCTFail("expected .fileNotFound, got \(err)")
            }
        }
    }

    func testValidateRejectsWrongExtension() throws {
        let data = TestWAVFactory.silence(samples: 10_000)
        let url  = tempDir.appendingPathComponent("audio.mp3")
        try data.write(to: url)
        XCTAssertThrowsError(try AudioSteganography.validate(audioAt: url)) { err in
            guard case .notAWavFile = err as? AudioError else {
                return XCTFail("expected .notAWavFile, got \(err)")
            }
        }
    }

    func testValidateRejectsNonRIFFFile() throws {
        let url = try writeWAV(Data("not-a-wav-file-content".utf8))
        XCTAssertThrowsError(try AudioSteganography.validate(audioAt: url)) { err in
            guard case .notAWavFile = err as? AudioError else {
                return XCTFail("expected .notAWavFile, got \(err)")
            }
        }
    }

    // MARK: - Capacity

    func testCapacityScalesWithSampleCount() throws {
        let small = try writeWAV(TestWAVFactory.silence(samples: 10_000), name: "small.wav")
        let large = try writeWAV(TestWAVFactory.silence(samples: 40_000), name: "large.wav")
        let cSmall = try AudioSteganography.capacity(ofAudioAt: small)
        let cLarge = try AudioSteganography.capacity(ofAudioAt: large)
        XCTAssertGreaterThan(cLarge, cSmall)
    }

    // MARK: - Embed / extract roundtrip

    func testRoundtripPreservesASCIIPayload() throws {
        let source = try writeWAV(TestWAVFactory.silence(samples: 10_000))
        let out    = tempDir.appendingPathComponent("out.wav")
        let payload = Data("hello secret world".utf8)

        try AudioSteganography.embed(data: payload, intoAudioAt: source, writingTo: out)
        let extracted = try AudioSteganography.extract(fromAudioAt: out)
        XCTAssertEqual(extracted, payload)
    }

    /// Guards against the classic null-strip bug: payloads that contain
    /// 0x00 bytes must survive a roundtrip intact.
    func testRoundtripPreservesBinaryWithNullBytes() throws {
        let source = try writeWAV(TestWAVFactory.silence(samples: 10_000))
        let out    = tempDir.appendingPathComponent("out.wav")
        let payload = Data([0x00, 0xFF, 0x00, 0xAA, 0x00, 0x55, 0x00])

        try AudioSteganography.embed(data: payload, intoAudioAt: source, writingTo: out)
        let extracted = try AudioSteganography.extract(fromAudioAt: out)
        XCTAssertEqual(extracted, payload)
    }

    func testRoundtripPreservesEmptyPayload() throws {
        let source = try writeWAV(TestWAVFactory.silence(samples: 1_000))
        let out    = tempDir.appendingPathComponent("out.wav")
        try AudioSteganography.embed(data: Data(), intoAudioAt: source, writingTo: out)
        let extracted = try AudioSteganography.extract(fromAudioAt: out)
        XCTAssertEqual(extracted, Data())
    }

    func testRoundtripLargePayload() throws {
        // 10 000 samples × 2 bytes/sample = 20 000 PCM bytes = 2500 payload bytes max.
        // Stay well under that.
        let source  = try writeWAV(TestWAVFactory.silence(samples: 10_000))
        let out     = tempDir.appendingPathComponent("out.wav")
        let payload = Data((0..<1_000).map { UInt8($0 & 0xFF) })

        try AudioSteganography.embed(data: payload, intoAudioAt: source, writingTo: out)
        let extracted = try AudioSteganography.extract(fromAudioAt: out)
        XCTAssertEqual(extracted, payload)
    }

    func testRoundtripSurvivesExtraChunksInHeader() throws {
        let url = try writeWAV(
            TestWAVFactory.silenceWithListChunk(samples: 10_000),
            name: "with-list.wav"
        )
        let out = tempDir.appendingPathComponent("out.wav")
        let payload = Data("chunks should not matter".utf8)

        try AudioSteganography.embed(data: payload, intoAudioAt: url, writingTo: out)
        let extracted = try AudioSteganography.extract(fromAudioAt: out)
        XCTAssertEqual(extracted, payload)
    }

    // MARK: - Capacity enforcement

    func testEmbedRejectsPayloadThatExceedsCapacity() throws {
        let source = try writeWAV(TestWAVFactory.silence(samples: 500))  // 1000 PCM bytes ≈ 125 payload bytes
        let out    = tempDir.appendingPathComponent("out.wav")
        let payload = Data(repeating: 0x42, count: 5_000)

        XCTAssertThrowsError(
            try AudioSteganography.embed(data: payload, intoAudioAt: source, writingTo: out)
        ) { err in
            guard case .insufficientCapacity = err as? AudioError else {
                return XCTFail("expected .insufficientCapacity, got \(err)")
            }
        }
    }

    // MARK: - Source preservation

    func testEmbedDoesNotModifySourceWhenOutputDiffers() throws {
        let sourceURL = try writeWAV(TestWAVFactory.silence(samples: 10_000))
        let originalBytes = try Data(contentsOf: sourceURL)
        let out = tempDir.appendingPathComponent("out.wav")

        try AudioSteganography.embed(
            data: Data("payload".utf8),
            intoAudioAt: sourceURL,
            writingTo: out
        )

        let bytesAfter = try Data(contentsOf: sourceURL)
        XCTAssertEqual(originalBytes, bytesAfter)
    }

    // MARK: - Stego output is still a valid WAV

    func testEmbeddedFileStaysValidWAV() throws {
        let source = try writeWAV(TestWAVFactory.silence(samples: 10_000))
        let out    = tempDir.appendingPathComponent("out.wav")
        try AudioSteganography.embed(
            data: Data("x".utf8),
            intoAudioAt: source,
            writingTo: out
        )
        XCTAssertNoThrow(try AudioSteganography.validate(audioAt: out))
    }

    // MARK: - Extraction from carrier with no payload

    func testExtractFromPristineWAVThrowsNoPayload() throws {
        let url = try writeWAV(TestWAVFactory.silence(samples: 10_000))
        XCTAssertThrowsError(try AudioSteganography.extract(fromAudioAt: url)) { err in
            guard case .noPayload = err as? AudioError else {
                return XCTFail("expected .noPayload, got \(err)")
            }
        }
    }

    // MARK: - Helpers

    private func writeWAV(_ data: Data, name: String = "test.wav") throws -> URL {
        let url = tempDir.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }
}
