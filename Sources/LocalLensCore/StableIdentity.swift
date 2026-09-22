import CryptoKit
import Foundation

public enum StableIdentity {
    public static func make(_ parts: String...) -> String {
        let bytes = SHA256.hash(data: Data(parts.joined(separator: "\u{1f}").utf8))
        return bytes.prefix(10).map { String(format: "%02x", $0) }.joined()
    }

    /// Full SHA-256 hex digest, used for snapshot and passage content hashes.
    public static func digest(_ parts: String...) -> String {
        let bytes = SHA256.hash(data: Data(parts.joined(separator: "\u{1f}").utf8))
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
