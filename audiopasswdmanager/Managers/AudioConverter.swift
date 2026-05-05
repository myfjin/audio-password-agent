import Foundation
import AVFoundation

/// Converts any Core Audio-readable file to a 16-bit PCM WAV suitable for steganography.
enum AudioConverter {

    enum Error: Swift.Error, LocalizedError {
        case unreadable(reason: String)
        case writeFailed(reason: String)

        var errorDescription: String? {
            switch self {
            case .unreadable(let r):  return "Cannot read audio file: \(r)"
            case .writeFailed(let r): return "Cannot write converted WAV: \(r)"
            }
        }
    }

    /// Returns a temporary PCM WAV URL. Caller is responsible for deleting it when done.
    static func convertToPCMWAV(from sourceURL: URL) throws -> URL {
        let sourceFile: AVAudioFile
        do {
            sourceFile = try AVAudioFile(forReading: sourceURL)
        } catch {
            throw Error.unreadable(reason: error.localizedDescription)
        }

        let outSettings: [String: Any] = [
            AVFormatIDKey:              kAudioFormatLinearPCM,
            AVSampleRateKey:            sourceFile.processingFormat.sampleRate,
            AVNumberOfChannelsKey:      sourceFile.processingFormat.channelCount,
            AVLinearPCMBitDepthKey:     16,
            AVLinearPCMIsFloatKey:      false,
            AVLinearPCMIsBigEndianKey:  false,
            AVLinearPCMIsNonInterleaved: false,
        ]

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".wav")

        let destFile: AVAudioFile
        do {
            destFile = try AVAudioFile(forWriting: tempURL, settings: outSettings)
        } catch {
            throw Error.writeFailed(reason: error.localizedDescription)
        }

        let chunkFrames: AVAudioFrameCount = 44100 * 30 // 30-second chunks
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: sourceFile.processingFormat,
            frameCapacity: min(chunkFrames, AVAudioFrameCount(sourceFile.length))
        ) else {
            throw Error.writeFailed(reason: "Could not allocate PCM buffer")
        }

        while sourceFile.framePosition < sourceFile.length {
            try sourceFile.read(into: buffer)
            guard buffer.frameLength > 0 else { break }
            do {
                try destFile.write(from: buffer)
            } catch {
                throw Error.writeFailed(reason: error.localizedDescription)
            }
        }

        return tempURL
    }
}
