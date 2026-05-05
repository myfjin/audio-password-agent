import Foundation

/// Generates minimal valid PCM WAV byte blobs for testing.
enum TestWAVFactory {

    /// Plain WAV with `samples` 16-bit mono silence samples and a standard
    /// 44-byte header (RIFF + fmt + data — nothing else).
    static func silence(samples: Int) -> Data {
        let bitsPerSample: UInt16 = 16
        let numChannels:   UInt16 = 1
        let sampleRate:    UInt32 = 44_100
        let byteRate   = sampleRate * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        let blockAlign = numChannels * (bitsPerSample / 8)
        let dataSize   = UInt32(samples) * UInt32(blockAlign)

        var wav = Data()
        wav.append(Data("RIFF".utf8))
        wav.append(UInt32(36 + dataSize).littleEndianData)
        wav.append(Data("WAVE".utf8))
        wav.append(Data("fmt ".utf8))
        wav.append(UInt32(16).littleEndianData)          // fmt chunk size (PCM)
        wav.append(UInt16(1).littleEndianData)           // format: PCM
        wav.append(numChannels.littleEndianData)
        wav.append(sampleRate.littleEndianData)
        wav.append(byteRate.littleEndianData)
        wav.append(blockAlign.littleEndianData)
        wav.append(bitsPerSample.littleEndianData)
        wav.append(Data("data".utf8))
        wav.append(dataSize.littleEndianData)
        wav.append(Data(count: Int(dataSize)))           // zero-filled samples
        return wav
    }

    /// Same as `silence`, but includes an extra `LIST` chunk between `fmt`
    /// and `data` — exercises the chunk-walker rather than a fixed 44-byte
    /// header offset.
    static func silenceWithListChunk(samples: Int) -> Data {
        let plain = silence(samples: samples)
        // Insert a 12-byte LIST chunk right before the "data" chunk.
        guard let dataRange = plain.range(of: Data("data".utf8)) else {
            return plain
        }
        var out = plain.prefix(dataRange.lowerBound)
        out.append(Data("LIST".utf8))
        out.append(UInt32(4).littleEndianData)
        out.append(Data("INFO".utf8))
        out.append(plain.suffix(from: dataRange.lowerBound))

        // Patch the RIFF chunk size field (bytes 4-7) to reflect 12 extra bytes.
        var patched = Data(out)
        let newRiffSize = UInt32(patched.count - 8).littleEndian
        withUnsafeBytes(of: newRiffSize) { buf in
            for (i, byte) in buf.enumerated() { patched[4 + i] = byte }
        }
        return patched
    }
}

extension UInt32 {
    var littleEndianData: Data {
        var v = self.littleEndian
        return Data(bytes: &v, count: MemoryLayout<UInt32>.size)
    }
}

extension UInt16 {
    var littleEndianData: Data {
        var v = self.littleEndian
        return Data(bytes: &v, count: MemoryLayout<UInt16>.size)
    }
}
