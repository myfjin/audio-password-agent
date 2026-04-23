import Foundation

public enum CryptoError: Error, Equatable {
    case keyDerivationFailed
    case invalidToken(reason: String)
    case decryptionFailed
    case encryptionFailed
}
