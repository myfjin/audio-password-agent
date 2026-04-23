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
