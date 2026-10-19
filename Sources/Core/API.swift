import CryptoKit
import Foundation

/// mlx.app, spoken to the way the wallet does: requests signed with the wallet key in the x-mlx-auth header
/// ("<wallet>|<ms>|<ed25519 signature>"), over a hash of the chain, wallet, time and the request itself
/// (lib/distributor/sign.ts). A signature is valid for five minutes and for that one request only.
struct API {
    static let base = "https://mlx.app"
    let account: String
    let chain: String
    let key: Curve25519.Signing.PrivateKey

    enum Failure: LocalizedError {
        case server(String), status(Int)
        var errorDescription: String? {
            switch self {
            case .server(let m): return m
            case .status(let s): return s == 401 ? "Sign in again to continue." : "mlx.app didn't answer (\(s)). Try again in a moment."
            }
        }
    }

    func get<T: Decodable>(_ path: String, as: T.Type) async throws -> T {
        try await send("GET", path, body: nil, as: T.self)
    }

    func post<T: Decodable>(_ path: String, _ body: [String: Any], as: T.Type) async throws -> T {
        try await send("POST", path, body: body, as: T.self)
    }

    private func send<T: Decodable>(_ method: String, _ path: String, body: [String: Any]?, as: T.Type) async throws -> T {
        let data = try body.map { try JSONSerialization.data(withJSONObject: $0, options: [.sortedKeys]) } ?? Data()
        let text = String(data: data, encoding: .utf8) ?? ""
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        let action = "\(method) \(path) \(WalletCrypto.sha256Hex(text))"
        let message = WalletCrypto.canonical(["type": "mlx-distributor", "chain": chain, "account": account, "action": action, "ts": ts])
        let signature = try key.signature(for: WalletCrypto.sha256(message))
        var req = URLRequest(url: URL(string: API.base + path)!)
        req.httpMethod = method
        req.timeoutInterval = 20
        req.setValue("\(account)|\(ts)|\(WalletCrypto.hex(signature))", forHTTPHeaderField: "x-mlx-auth")
        req.setValue("MLXiOS/\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "1")", forHTTPHeaderField: "x-mlx-client")
        if body != nil {
            req.httpBody = data
            req.setValue("application/json", forHTTPHeaderField: "content-type")
        }
        return try await API.decode(req, as: T.self)
    }

    static func decode<T: Decodable>(_ req: URLRequest, as: T.Type) async throws -> T {
        let (data, res) = try await URLSession.shared.data(for: req)
        let status = (res as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            if let e = try? JSONDecoder().decode(ErrorBody.self, from: data), let m = e.error { throw Failure.server(m) }
            throw Failure.status(status)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Unsigned public reads: the chain id and the wallet name for a public key.
    static func open<T: Decodable>(_ path: String, as: T.Type) async throws -> T {
        var req = URLRequest(url: URL(string: base + path)!)
        req.timeoutInterval = 20
        return try await decode(req, as: T.self)
    }

    private struct ErrorBody: Decodable { let error: String? }
}

// MARK: wire types

struct StatsReply: Decodable { let chain: String }

struct KeyReply: Decodable {
    let account: Account
    struct Account: Decodable { let name: String }
}

struct OK: Decodable { let ok: Bool? }

/// GET /api/companion/me (lib/companion.ts).
struct Me: Decodable, Equatable {
    let account: String
    let chain: String
    let usdPerMlx: Double
    let earning: Earning
    let nodes: [Node]
    let macs: [Mac]

    struct Earning: Decodable, Equatable {
        let today: String
        let locked: String
        let perDayMax: String
        let free: Bool
    }

    struct Node: Decodable, Equatable, Identifiable {
        let id: Int
        let tier: String
        let name: String
        let reward: String
        let unlockAt: Double?
    }

    struct Mac: Decodable, Equatable, Identifiable {
        var id: String { pk }
        let pk: String
        let name: String
        let chip: String
        let memoryGB: Double
        let os: String
        let linkedAt: Double
        let online: Bool
        let seen: Double?
        let app: String
        let state: String
        let reason: String
        let thermal: String
        let onAC: Bool
        let limits: Limits
        let tokPerSec: Double?
        let tps: Double?
        let today: Today?
        let carries: Carry?
        let pending: Int

        struct Today: Decodable, Equatable { let jobs: Double; let tokens: Double; let passRate: Double? }
        struct Carry: Decodable, Equatable { let tier: String; let name: String; let units: Double; let full: Double }
    }

    struct Limits: Decodable, Equatable {
        var idleMinutes: Double?
        var memoryPct: Double?
        var hoursFrom: Double?
        var hoursTo: Double?
        var onlyOnAC: Bool?
        var maxThermal: String?
        var paused: Bool?
    }
}

extension Me.Mac {
    var paused: Bool { limits.paused ?? false }
    var manual: Bool { (limits.idleMinutes ?? 3) == 0 }
    var working: Bool { online && (state == "working" || state == "calibrating" || state == "downloading") }

    enum Status { case working, ready, paused, stopped, waiting, offline }
    var status: Status {
        if !online { return .offline }
        if paused || state == "paused" { return manual ? .stopped : .paused }
        if working { return .working }
        if state == "idle-waiting" && reason == "Ready" { return .ready }
        return .waiting
    }

    /// An SF Symbol for the kind of Mac, from the name the owner gave it.
    var symbol: String {
        let n = name.lowercased()
        if n.contains("studio") { return "macstudio" }
        if n.contains("mini") { return "macmini" }
        if n.contains("book") || n.contains("air") { return "laptopcomputer" }
        if n.contains("pro") && !n.contains("book") { return "macpro.gen3" }
        return "desktopcomputer"
    }
}

enum Amount {
    /// "12.42" from MLX base units (6 decimals).
    static func mlx(_ units: String, max: Int? = nil) -> String {
        let v = (Double(units) ?? 0) / 1_000_000
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        f.maximumFractionDigits = max ?? (v == 0 ? 0 : v < 1 ? 4 : v < 1000 ? 2 : 0)
        return f.string(from: NSNumber(value: v)) ?? "0"
    }

    static func usd(_ units: String, price: Double) -> String {
        let v = (Double(units) ?? 0) / 1_000_000 * price
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.locale = Locale(identifier: "en_US")
        f.maximumFractionDigits = v < 1 ? 4 : 2
        f.minimumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? "$0.00"
    }

    static func compact(_ v: Double) -> String {
        switch v {
        case 1_000_000_000...: return String(format: "%.1fB", v / 1_000_000_000)
        case 1_000_000...: return String(format: "%.1fM", v / 1_000_000)
        case 10_000...: return String(format: "%.0fK", v / 1000)
        case 1000...: return String(format: "%.1fK", v / 1000)
        default: return String(Int(v))
        }
    }
}
