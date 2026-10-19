import Foundation

/// Example data for App Store screenshots (launch argument -demo). Never shown in normal use.
enum Demo {
    static let me: Me = {
        let now = Date().timeIntervalSince1970 * 1000
        func mac(_ pk: String, _ name: String, _ chip: String, _ mem: Double, state: String, reason: String = "", online: Bool = true,
                 tps: Double?, cal: Double, jobs: Double, tokens: Double, carries: Me.Mac.Carry?, paused: Bool = false) -> Me.Mac {
            Me.Mac(pk: pk, name: name, chip: chip, memoryGB: mem, os: "macOS 26.1", linkedAt: now - 9 * 86_400_000, online: online,
                   seen: online ? now - 20_000 : now - 3 * 3_600_000, app: "0.8.0", state: state, reason: reason, thermal: "nominal", onAC: true,
                   limits: Me.Limits(idleMinutes: 3, memoryPct: 50, hoursFrom: 0, hoursTo: 0, onlyOnAC: true, maxThermal: "fair", paused: paused),
                   tokPerSec: cal, tps: tps, today: .init(jobs: jobs, tokens: tokens, passRate: 1), carries: carries, pending: 0)
        }
        return Me(
            account: "alex.mlx",
            chain: "mlx-1",
            usdPerMlx: 0.01,
            earning: .init(today: "214380000", locked: "3462900000", perDayMax: "440000000", free: false),
            nodes: [
                .init(id: 128, tier: "MX", name: "Pro Latest", reward: "149968000000", unlockAt: (Date().timeIntervalSince1970 + 547 * 86_400) * 1000),
                .init(id: 1042, tier: "L", name: "Ultra", reward: "399896000000", unlockAt: (Date().timeIntervalSince1970 + 365 * 86_400) * 1000)
            ],
            macs: [
                mac("03a1", "Mac Studio", "M3 Ultra", 192, state: "working", tps: 182.4, cal: 186, jobs: 1408, tokens: 4_218_600,
                    carries: .init(tier: "L", name: "Ultra", units: 40, full: 40)),
                mac("02b7", "Alex's MacBook Pro", "M5 Max", 64, state: "working", tps: 141.9, cal: 148, jobs: 962, tokens: 2_874_100,
                    carries: .init(tier: "MX", name: "Pro Latest", units: 15, full: 15)),
                mac("03c4", "Mac mini", "M4", 16, state: "idle-waiting", reason: "Waiting for idle", tps: nil, cal: 96, jobs: 211, tokens: 581_300,
                    carries: nil)
            ]
        )
    }()
}
