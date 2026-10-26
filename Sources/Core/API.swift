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

/// GET /api/companion/me (lib/companion.ts). Fields added for MLX.app 1.1 are optional, so an older mlx.app still decodes.
struct Me: Decodable, Equatable {
    let account: String
    let chain: String
    let usdPerMlx: Double
    let earning: Earning
    let nodes: [Seat]
    let macs: [Mac]
    var network: Network?
    var node: NodeApp?
    var live: Live?

    struct Network: Decodable, Equatable { let name: String; let chain: String; let height: Int? }
    /// MLX Node, the menu bar app: the version mlx.app offers for download.
    struct NodeApp: Decodable, Equatable { let latest: String? }
    /// Mined MLX not yet settled (the running hour) and how fast it grows while a Mac works (MLX a second).
    struct Live: Decodable, Equatable { let at: Double; let pending: String; let rate: Double; let state: String }

    struct Earning: Decodable, Equatable {
        let today: String
        let locked: String
        let perDayMax: String
        let free: Bool
        var seat: String?
        var throttled: Bool?
        var perHourMax: Double?
        var freePerHour: Double?
        var lockDays: Int?
    }

    /// A dedicated seat (JSON and ids keep the old word "node").
    struct Seat: Decodable, Equatable, Identifiable {
        let id: Int
        let tier: String
        let name: String
        let reward: String
        let unlockAt: Double?
        var latest: Bool?
        var perHour: Double?
        var lockDays: Int?
        var carriedBy: String?
        var carriedPerHour: Double?
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
        var art: String?
        var model: String?
        var year: Int?
        var geo: Geo?
        var perHour: Double?

        struct Today: Decodable, Equatable { let jobs: Double; let tokens: Double; let passRate: Double? }
        struct Carry: Decodable, Equatable { let tier: String; let name: String; let units: Double; let full: Double; var id: Int? }
        struct Geo: Decodable, Equatable { let city: String?; let region: String?; let country: String? }
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

extension Me {
    var dedicated: Bool { (earning.seat ?? (earning.free ? "free" : "dedicated")) == "dedicated" }
    var throttled: Bool { earning.throttled ?? earning.free }
    /// Biggest seat first (the one the seat line names).
    var topSeat: Seat? { nodes.max { ($0.perHour ?? 0) < ($1.perHour ?? 0) } }
    var lockDays: Int { earning.lockDays ?? (dedicated ? 10 : 30) }
    var mining: Bool { live?.state == "mining" && (live?.rate ?? 0) > 0 }
    var paused: Bool { live?.state == "paused" }
    func mac(_ pk: String?) -> Mac? { pk.flatMap { p in macs.first { $0.pk == p } } }
}

extension Me.Seat {
    /// "Pro seat #128", "Core Latest seat #1,042"
    var title: String { "\(name) seat #\(id.formatted())" }
}

extension Me.Mac {
    var paused: Bool { limits.paused ?? false }
    var manual: Bool { (limits.idleMinutes ?? 3) == 0 }
    var working: Bool { online && (state == "working" || state == "calibrating" || state == "downloading") }
    /// Stepping aside for MLX Harness (mlx://yield): paused for a few minutes, the owner's own pause untouched.
    var yielded: Bool { online && state == "paused" && reason.localizedCaseInsensitiveContains("Harness") }

    enum Status { case working, ready, paused, stopped, harness, waiting, offline }
    var status: Status {
        if !online { return .offline }
        if yielded && !paused { return .harness }
        if paused || state == "paused" { return manual ? .stopped : .paused }
        if working { return .working }
        // waiting for its next AI job (a free seat's short gap, or ready on a dedicated one) still counts as working
        if state == "idle-waiting" && (reason == "Ready" || reason.hasPrefix("Free seat") || reason == "No work right now") { return .ready }
        return .waiting
    }

    /// The line under the name: what it's doing when that isn't obvious, else the model, chip and memory.
    var detail: String {
        [chip, memoryGB > 0 ? "\(Int(memoryGB)) GB" : nil].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// Under the name in lists: "M3 Ultra · 96 GB" when the name already says the model, else "MacBook Pro 16-inch · M4 Max".
    var rowLine: String {
        if name.localizedCaseInsensitiveContains(modelName) || modelName == "Mac" { return detail }
        return [modelName, chip].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// "MacBook Pro 14-inch" from mlx.app (Apple's model identifier), else the kind of Mac from its name.
    var modelName: String {
        if let m = model, !m.isEmpty, m != "Mac" { return m }
        let n = name.lowercased()
        if n.contains("studio") { return "Mac Studio" }
        if n.contains("mini") { return "Mac mini" }
        if n.contains("air") { return "MacBook Air" }
        if n.contains("book") { return "MacBook Pro" }
        if n.contains("imac") { return "iMac" }
        return "Mac"
    }

    /// The drawing in the asset catalog (mac-<art>, the same drawings as mlx.app/macs).
    var picture: String {
        if let a = art, !a.isEmpty { return "mac-\(a)" }
        switch modelName {
        case "Mac Studio": return "mac-mac-studio"
        case "Mac mini": return "mac-mac-mini"
        case "MacBook Air": return "mac-macbook-air"
        case "MacBook Pro": return "mac-macbook-pro"
        case "iMac": return "mac-imac"
        default: return "mac-mac"
        }
    }

    var place: String? {
        guard let g = geo else { return nil }
        let parts = [g.city, g.country].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// MLX Node's version is older than the one mlx.app offers.
    func outdated(latest: String?) -> Bool {
        guard let latest, !app.isEmpty else { return false }
        return app.compare(latest, options: .numeric) == .orderedAscending
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

    /// Six decimals, like the wallet: "12.420000".
    static func mlx6(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        f.minimumFractionDigits = 6
        f.maximumFractionDigits = 6
        return f.string(from: NSNumber(value: v)) ?? "0.000000"
    }

    /// A mining rate the way mlx.app and MLX Node write it: "~0.83 MLX/h", "~0.0417 MLX/h".
    static func rate(_ perHour: Double) -> String {
        let digits = perHour < 0.1 ? 4 : 2
        var s = String(format: "%.\(digits)f", perHour)
        while s.contains("."), s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return "~\(s) MLX/h"
    }

    static func usd(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.locale = Locale(identifier: "en_US")
        f.maximumFractionDigits = v < 1 ? 4 : 2
        f.minimumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? "$0.00"
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
