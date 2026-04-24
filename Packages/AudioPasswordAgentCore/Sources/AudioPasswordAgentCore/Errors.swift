import Foundation

public enum CryptoError: Error, Equatable {
    case keyDerivationFailed
    case invalidToken(reason: String)
    case decryptionFailed
    case encryptionFailed
}

public enum AudioError: Error, Equatable {
    case fileNotFound(path: String)
    case notAWavFile(reason: String)
    case missingDataChunk
    case insufficientCapacity(requiredBits: Int, availableBits: Int)
    case noPayload
    case corruptPayload(reason: String)
    case ioFailed(reason: String)
}

extension AudioError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):          return "File not found: \(path)"
        case .notAWavFile(let reason):         return "Not a WAV file: \(reason)"
        case .missingDataChunk:                return "WAV file has no PCM data chunk"
        case .insufficientCapacity(let req, let avail):
            return "WAV too small: need \(req) bits, have \(avail) bits"
        case .noPayload:                       return "WAV file has no embedded payload (magic bytes mismatch)"
        case .corruptPayload(let reason):      return "Corrupt payload: \(reason)"
        case .ioFailed(let reason):            return "I/O error: \(reason)"
        }
    }
}

public enum VaultError: Error, Equatable {
    case vaultDirectoryUnreadable(reason: String)
    case corruptConfig(reason: String)
    case corruptCredential(reason: String)
    case wrongMasterPassword
}
