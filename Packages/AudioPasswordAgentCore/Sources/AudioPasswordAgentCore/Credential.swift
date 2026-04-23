import Foundation

/// Public read-only view of a credential stored in a WAV file —
/// everything except the plaintext password.
public struct CredentialInfo: Equatable, Sendable {
    public let service:   String
    public let username:  String
    public let storedAt:  String
    public let audioFile: URL
}

/// Full credential including the decrypted password.
public struct Credential: Equatable, Sendable {
    public let service:   String
    public let username:  String
    public let password:  String
    public let storedAt:  String
    public let metadata:  [String: String]
}
