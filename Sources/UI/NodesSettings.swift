import SwiftUI

/// The wallet's dedicated seats (ids, routes and JSON keep the old word "node").
struct NodesView: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        List {
            if let me = store.me {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        SeatLine(me: me)
                        Text(intro(me)).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 6)
                }
                if !me.nodes.isEmpty {
                    Section("Dedicated seats") {
                        ForEach(me.nodes.sorted { ($0.perHour ?? 0) > ($1.perHour ?? 0) || ($0.perHour == $1.perHour && $0.id < $1.id) }) { n in
                            SeatRow(seat: n, mac: me.mac(n.carriedBy))
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Seats")
        .refreshable { await store.refresh() }
        .animation(.smooth(duration: 0.35), value: store.me?.nodes)
    }

    private func intro(_ me: Me) -> String {
        if me.dedicated {
            return "AI jobs back to back on the Macs that carry a seat, the biggest seat on the biggest Mac. Mined MLX unlocks after \(me.lockDays) days."
        }
        return "Your Macs run on a free seat: short AI jobs now and then, up to \(Amount.rate(me.earning.freePerHour ?? 1.0 / 24)) for the wallet. Mined MLX unlocks after \(me.lockDays) days."
    }
}

struct SeatRow: View {
    let seat: Me.Seat
    let mac: Me.Mac?

    var body: some View {
        HStack(spacing: 14) {
            SeatGlyph(seat: seat)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(seat.title).font(.body.weight(.semibold)).lineLimit(1)
                    if seat.latest ?? false {
                        Text("Newest chip").font(.caption2.weight(.semibold)).foregroundStyle(Brand.orange)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Brand.orange.opacity(0.12), in: Capsule())
                    }
                }
                Text(carrier).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                if let r = rewardLine { Text(r).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 6)
            if let r = seat.perHour, r > 0 {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(Amount.rate(r).replacingOccurrences(of: " MLX/h", with: "")).font(.callout.weight(.semibold).monospacedDigit())
                    Text("MLX/h").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var carrier: String {
        guard let mac else { return "Waiting for a Mac to carry it" }
        if let r = seat.carriedPerHour, let full = seat.perHour, r + 0.0001 < full {
            return "On \(mac.name), mining \(Amount.rate(r)) (a smaller chip class)"
        }
        return "On \(mac.name) · full speed"
    }

    /// Seats bought before 20 Oct 2026 came with MLX up front, locked until a date.
    private var rewardLine: String? {
        guard (Double(seat.reward) ?? 0) > 0, let u = seat.unlockAt, u > Date().timeIntervalSince1970 * 1000 else { return nil }
        return "\(Amount.mlx(seat.reward, max: 0)) MLX unlocks \(Date(timeIntervalSince1970: u / 1000).formatted(date: .abbreviated, time: .omitted))"
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: Store
    @State private var confirmSignOut = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Emblem(size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.me?.account ?? "–").font(.headline)
                        Text("Signed in with your MLX wallet").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            Section {
                Toggle("Notifications", isOn: Binding(get: { store.pushOn }, set: { on in Task { await store.setPush(on) } }))
                Toggle("Lock with Face ID", isOn: $store.lockWithFaceID)
            } footer: {
                Text(store.pushError ?? "Tells you when a Mac stops or comes back, and what your Macs mined each day.")
                    .foregroundStyle(store.pushError == nil ? Color.secondary : Color.red)
            }
            Section {
                HStack {
                    Text("Network")
                    Spacer()
                    HStack(spacing: 6) {
                        Pulse(color: Brand.fullSpeed, active: true)
                        Text(store.me?.network?.name ?? "MLX Mainnet")
                    }
                    .foregroundStyle(.secondary)
                }
                LabeledContent("Chain", value: store.me?.network?.chain ?? store.me?.chain ?? "–")
                if let h = store.me?.network?.height {
                    LabeledContent("Block") { Text(h.formatted()).monospacedDigit().contentTransition(.numericText()) }
                }
            } footer: {
                Text("MLX.app talks to the live MLX network at mlx.app: the same wallet, seats and Macs you see there.")
            }
            Section {
                Link(destination: URL(string: "mailto:support@mlx.app")!) { Label("Help and support", systemImage: "questionmark.circle") }
                Link(destination: URL(string: "https://mlx.app/privacy")!) { Label("Privacy", systemImage: "hand.raised") }
                Link(destination: URL(string: "https://mlx.app/terms")!) { Label("Terms", systemImage: "doc.text") }
                Link(destination: URL(string: "https://mlx.app")!) { Label("mlx.app", systemImage: "globe") }
            } footer: {
                Text("MLX.app \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "")) · MLX Network is not affiliated with Apple Inc.")
            }
            Section {
                Button("Sign out", role: .destructive) { confirmSignOut = true }
            } footer: {
                Text("Signing out removes your wallet key from this iPhone. Your wallet and Macs aren't affected.")
            }
        }
        .navigationTitle("Settings")
        .animation(.smooth(duration: 0.35), value: store.me?.network)
        .confirmationDialog("Sign out of MLX.app?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { Task { await store.signOut() } }
        }
    }
}
