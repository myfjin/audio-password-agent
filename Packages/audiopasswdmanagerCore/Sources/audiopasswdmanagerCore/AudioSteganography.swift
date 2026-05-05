import Foundation

/// Hides an arbitrary byte payload inside the PCM data of a WAV file by
/// overwriting the least-significant bit (LSB) of each audio byte.
///
/// Payload framing on disk:
/// ```
/// ┌──────────┬──────────────┬─────────────────────┐
/// │ magic    │ length (BE)  │ payload bytes       │
/// │ 4 bytes  │ 4 bytes      │ N bytes             │
/// │ "APA1"   │ UInt32       │                     │
/// └──────────┴──────────────┴─────────────────────┘
/// ```
/// Each of these bytes occupies 8 PCM samples in the carrier (1 bit per
/// sample). The magic marker distinguishes a carrier WAV that holds a
/// payload from one that does not.
public enum AudioSteganography {

    /// ASCII "APA1" — stands for Audio Password Agent, format v1.
    public static let magic: [UInt8] = [0x41, 0x50, 0x41, 0x31]
    public static let headerByteCount = 4 + 4   // magic + length

    // MARK: - Validation

    public static func validate(audioAt url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioError.fileNotFound(path: url.path)
        }
        guard url.pathExtension.lowercased() == "wav" else {
            throw AudioError.notAWavFile(reason: "extension is \"\(url.pathExtension)\"")
        }
        let data = try readData(at: url)
        _ = try WAVParser.locateDataChunk(in: data)
    }

    /// Maximum payload size (in bytes) that a WAV file can carry.
    public static func capacity(ofAudioAt url: URL) throws -> Int {
        let data = try readData(at: url)
        let range = try WAVParser.locateDataChunk(in: data)
        let totalBytes = range.count / 8      // 1 bit per PCM byte
        return max(0, totalBytes - headerByteCount)
    }

    // MARK: - Embed

    public static func embed(
        data payload: Data,
        intoAudioAt source: URL,
        writingTo output: URL
    ) throws {
        var wav = try readData(at: source)
        let pcm = try WAVParser.locateDataChunk(in: wav)

        // Build framed bitstream: [magic][length BE][payload]
        var frame = Data(capacity: headerByteCount + payload.count)
        frame.append(contentsOf: magic)
        var lengthBE = UInt32(payload.count).bigEndian
        withUnsafeBytes(of: &lengthBE) { frame.append(contentsOf: $0) }
        frame.append(payload)

        let bitsRequired = frame.count * 8
        guard bitsRequired <= pcm.count else {
            throw AudioError.insufficientCapacity(
                requiredBits:  bitsRequired,
                availableBits: pcm.count
            )
        }

        // Overwrite LSB of each PCM byte. Bit order per byte: MSB → LSB.
        var bitIndex = 0
        for byte in frame {
            for shift in (0..<8).reversed() {
                let target = pcm.lowerBound + bitIndex
                let bit = UInt8((byte >> shift) & 1)
                wav[target] = (wav[target] & 0xFE) | bit
                bitIndex += 1
            }
        }

        do {
            try wav.write(to: output, options: .atomic)
        } catch {
            throw AudioError.ioFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - Extract

    public static func extract(fromAudioAt url: URL) throws -> Data {
        let wav = try readData(at: url)
        let pcm = try WAVParser.locateDataChunk(in: wav)

        guard pcm.count >= headerByteCount * 8 else {
            throw AudioError.noPayload
        }

        // Read magic (32 bits)
        var magicBytes = [UInt8](repeating: 0, count: 4)
        for byteIx in 0..<4 {
            var b: UInt8 = 0
            for bitIx in 0..<8 {
                let src = pcm.lowerBound + byteIx * 8 + bitIx
                b = (b << 1) | (wav[src] & 1)
            }
            magicBytes[byteIx] = b
        }
        guard magicBytes == magic else {
            throw AudioError.noPayload
        }

        // Read length (next 32 bits, big-endian)
        var length: UInt32 = 0
        for i in 0..<32 {
            let src = pcm.lowerBound + 32 + i
            length = (length << 1) | UInt32(wav[src] & 1)
        }
        let payloadByteCount = Int(length)
        let availableBytes   = pcm.count / 8 - headerByteCount
        guard payloadByteCount >= 0, payloadByteCount <= availableBytes else {
            throw AudioError.corruptPayload(
                reason: "length \(payloadByteCount) exceeds capacity \(availableBytes)"
            )
        }

        // Read payload
        var payload = Data(count: payloadByteCount)
        let payloadBitStart = pcm.lowerBound + headerByteCount * 8
        for byteIx in 0..<payloadByteCount {
            var b: UInt8 = 0
            for bitIx in 0..<8 {
                let src = payloadBitStart + byteIx * 8 + bitIx
                b = (b << 1) | (wav[src] & 1)
            }
            payload[byteIx] = b
        }
        return payload
    }

    // MARK: - Private

    private static func readData(at url: URL) throws -> Data {
        do {
            return try Data(contentsOf: url)
        } catch CocoaError.fileReadNoSuchFile {
            throw AudioError.fileNotFound(path: url.path)
        } catch {
            throw AudioError.ioFailed(reason: error.localizedDescription)
        }
    }
}
