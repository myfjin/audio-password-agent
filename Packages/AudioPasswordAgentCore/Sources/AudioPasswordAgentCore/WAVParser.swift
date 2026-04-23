import Foundation

/// Locates the PCM `data` sub-chunk inside a RIFF/WAVE file.
///
/// Walks the chunk list instead of assuming the fixed 44-byte header offset,
/// so files with extra chunks like `LIST`, `JUNK`, or `bext` still work.
enum WAVParser {

    /// Returns the absolute byte range of the `data` chunk's payload.
    static func locateDataChunk(in wav: Data) throws -> Range<Int> {
        guard wav.count >= 12 else {
            throw AudioError.notAWavFile(reason: "file too short (\(wav.count) bytes)")
        }
        guard wav.prefix(4) == Data("RIFF".utf8) else {
            throw AudioError.notAWavFile(reason: "missing RIFF header")
        }
        guard wav.subdata(in: 8..<12) == Data("WAVE".utf8) else {
            throw AudioError.notAWavFile(reason: "missing WAVE marker")
        }

        var cursor = 12
        while cursor + 8 <= wav.count {
            let chunkID = wav.subdata(in: cursor ..< cursor + 4)
            let size = wav.subdata(in: cursor + 4 ..< cursor + 8)
                .withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }

            let payloadStart = cursor + 8
            let payloadEnd   = payloadStart + Int(size)

            if chunkID == Data("data".utf8) {
                guard payloadEnd <= wav.count else {
                    throw AudioError.notAWavFile(reason: "data chunk truncated")
                }
                return payloadStart ..< payloadEnd
            }

            // RIFF chunks are padded to an even byte count.
            cursor = payloadEnd + (Int(size) & 1)
        }
        throw AudioError.missingDataChunk
    }
}
