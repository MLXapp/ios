import Foundation

/// Example data for App Store and TestFlight screenshots (launch argument -demo). Never shown in normal use.
/// The same example wallet as mlx.app's homepage product shot: luca.mlx with Pro seat #128 and Core seat #1,042.
enum Demo {
    static let me: Me = {
        let now = Date().timeIntervalSince1970 * 1000
        func mac(_ pk: String, _ name: String, _ chip: String, _ mem: Double, art: String, model: String, year: Int,
                 state: String, reason: String = "", online: Bool = true, tps: Double?, cal: Double, jobs: Double, tokens: Double,
                 carries: Me.Mac.Carry?, perHour: Double?, city: String, country: String, idle: Double = 0) -> Me.Mac {
            Me.Mac(pk: pk, name: name, chip: chip, memoryGB: mem, os: "macOS 26.1", linkedAt: now - 6 * 86_400_000, online: online,
                   seen: online ? now - 20_000 : now - 3 * 3_600_000, app: "0.9.6", state: state, reason: reason, thermal: "nominal", onAC: true,
                   limits: Me.Limits(idleMinutes: idle, memoryPct: 50, hoursFrom: 0, hoursTo: 0, onlyOnAC: true, maxThermal: "fair", paused: false),
                   tokPerSec: cal, tps: tps, today: .init(jobs: jobs, tokens: tokens, passRate: 0.99), carries: carries, pending: 0,
                   art: art, model: model, year: year, geo: .init(city: city, region: nil, country: country), perHour: perHour)
        }
        return Me(
            account: "luca.mlx",
            chain: "mlx-1",
            usdPerMlx: 0.0103,
            earning: .init(today: "41206114", locked: "612480000", perDayMax: "100000000", free: false,
                           seat: "dedicated", throttled: false, perHourMax: 100.0 / 24, freePerHour: 1.0 / 24, lockDays: 7),
            nodes: [
                .init(id: 128, tier: "M", name: "Pro", reward: "0", unlockAt: nil, latest: false, perHour: 80.0 / 24, lockDays: 7,
                      carriedBy: "03a1", carriedPerHour: 80.0 / 24),
                .init(id: 1042, tier: "S", name: "Core", reward: "0", unlockAt: nil, latest: false, perHour: 20.0 / 24, lockDays: 10,
                      carriedBy: "02b7", carriedPerHour: 20.0 / 24)
            ],
            macs: [
                mac("03a1", "Mac Studio", "M3 Ultra", 96, art: "mac-studio", model: "Mac Studio", year: 2025, state: "working",
                    tps: 386.2, cal: 392, jobs: 1408, tokens: 225_280, carries: .init(tier: "M", name: "Pro", units: 10, full: 10, id: 128),
                    perHour: 80.0 / 24, city: "Stockholm", country: "Sweden"),
                mac("02b7", "Luca's MacBook Pro", "M4 Max", 64, art: "macbook-pro", model: "MacBook Pro 16-inch", year: 2024, state: "working",
                    tps: 341.9, cal: 348, jobs: 962, tokens: 153_920, carries: .init(tier: "S", name: "Core", units: 2.5, full: 2.5, id: 1042),
                    perHour: 20.0 / 24, city: "Stockholm", country: "Sweden"),
                mac("03c4", "MacBook Air", "M4", 24, art: "macbook-air", model: "MacBook Air 13-inch", year: 2025, state: "paused",
                    reason: "Paused for MLX Harness", tps: nil, cal: 168, jobs: 211, tokens: 33_760, carries: nil, perHour: nil,
                    city: "Seoul", country: "South Korea")
            ],
            network: .init(name: "MLX Mainnet", chain: "mlx-1", height: 2184),
            node: .init(latest: "0.9.6"),
            live: .init(at: now, pending: "1937420", rate: 100.0 / 24 / 3600, state: "mining")
        )
    }()
}
