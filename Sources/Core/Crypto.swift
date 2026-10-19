import CryptoKit
import Foundation

/// The wallet's keys, exactly as mlx.app makes them (lib/chain/crypto.ts): the 32-byte seed (the passkey's user
/// handle, or the entropy of the 24-word recovery phrase) → HKDF-SHA256 → an Ed25519 signing key.
enum WalletCrypto {
    static func signingKey(seed: Data) throws -> Curve25519.Signing.PrivateKey {
        let derived = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: seed),
            salt: Data("mlx-wallet-v1".utf8),
            info: Data("ed25519-signing-key".utf8),
            outputByteCount: 32
        )
        let raw = derived.withUnsafeBytes { Data($0) }
        return try Curve25519.Signing.PrivateKey(rawRepresentation: raw)
    }

    static func hex(_ d: Data) -> String { d.map { String(format: "%02x", $0) }.joined() }

    static func sha256(_ s: String) -> Data { Data(SHA256.hash(data: Data(s.utf8))) }
    static func sha256Hex(_ s: String) -> String { hex(sha256(s)) }

    /// JSON with sorted keys and no spaces, like the site's canonical(); values here are strings and integers.
    static func canonical(_ fields: [String: Any]) -> String {
        let parts = fields.keys.sorted().map { key -> String in
            let v = fields[key]!
            let value: String
            if let s = v as? String { value = jsonString(s) }
            else if let i = v as? Int { value = String(i) }
            else if let i = v as? Int64 { value = String(i) }
            else { value = jsonString(String(describing: v)) }
            return "\(jsonString(key)):\(value)"
        }
        return "{" + parts.joined(separator: ",") + "}"
    }

    /// A string as JSON.stringify writes it.
    static func jsonString(_ s: String) -> String {
        var out = "\""
        for u in s.unicodeScalars {
            switch u {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            default:
                if u.value < 0x20 { out += String(format: "\\u%04x", u.value) } else { out.unicodeScalars.append(u) }
            }
        }
        return out + "\""
    }
}

/// The 24-word recovery phrase (BIP-39, English) → the 32-byte wallet seed.
enum RecoveryPhrase {
    enum Problem: LocalizedError {
        case words, unknown(String), checksum
        var errorDescription: String? {
            switch self {
            case .words: return "Use the 24-word phrase from your MLX wallet."
            case .unknown(let w): return "\u{201C}\(w)\u{201D} isn't a recovery phrase word. Check the spelling."
            case .checksum: return "That recovery phrase isn't valid. Check the words and their order."
            }
        }
    }

    private static let list: [String] = {
        guard let url = Bundle.main.url(forResource: "bip39-english", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").map(String.init)
    }()
    private static let index: [String: Int] = Dictionary(uniqueKeysWithValues: list.enumerated().map { ($1, $0) })

    static func seed(from phrase: String) throws -> Data {
        let words = phrase.lowercased().split(whereSeparator: { $0.isWhitespace || $0 == "," }).map(String.init)
        guard words.count == 24 else { throw Problem.words }
        var bits: [Bool] = []
        for w in words {
            guard let i = index[w] else { throw Problem.unknown(w) }
            for b in (0..<11).reversed() { bits.append((i >> b) & 1 == 1) }
        }
        // 256 bits of entropy, then 8 bits of checksum (the first byte of its SHA-256)
        var entropy = Data(count: 32)
        for byte in 0..<32 {
            var v: UInt8 = 0
            for b in 0..<8 where bits[byte * 8 + b] { v |= 1 << (7 - b) }
            entropy[byte] = v
        }
        var check: UInt8 = 0
        for b in 0..<8 where bits[256 + b] { check |= 1 << (7 - b) }
        guard Data(SHA256.hash(data: entropy)).first == check else { throw Problem.checksum }
        return entropy
    }
}
