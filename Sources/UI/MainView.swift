import SwiftUI

enum Route: Hashable {
    case mac(String), nodes, settings
}

/// One layout for both: on iPhone the list pushes each page; on iPad the list is a sidebar beside the page.
struct MainView: View {
    @EnvironmentObject private var store: Store
    @State private var route: Route?
    @State private var columns: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            Sidebar(route: $route)
                .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 440)
        } detail: {
            NavigationStack {
                switch route {
                case .mac(let pk):
                    if let mac = store.me?.macs.first(where: { $0.pk == pk }) { MacDetailView(mac: mac) } else { Overview() }
                case .nodes: NodesView()
                case .settings: SettingsView()
                case nil: Overview()
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

struct Sidebar: View {
    @EnvironmentObject private var store: Store
    @Binding var route: Route?

    var body: some View {
        List(selection: $route) {
            if let me = store.me {
                Section {
                    SummaryCard(me: me)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                Section("Macs") {
                    if me.macs.isEmpty {
                        NoMacs()
                    }
                    ForEach(me.macs) { mac in
                        NavigationLink(value: Route.mac(mac.pk)) { MacRow(mac: mac) }
                            .accessibilityIdentifier("mac-\(mac.name)")
                    }
                }
                Section {
                    NavigationLink(value: Route.nodes) {
                        HStack {
                            Label("Seats", systemImage: "square.stack.3d.up.fill")
                            Spacer()
                            Text(me.nodes.isEmpty ? "Free" : "\(me.nodes.count)").foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                    .accessibilityIdentifier("nodes")
                    NavigationLink(value: Route.settings) { Label("Settings", systemImage: "gearshape.fill") }
                        .accessibilityIdentifier("settings")
                } footer: {
                    NetworkLine(me: me).padding(.top, 6)
                }
            } else if let e = store.error {
                ContentUnavailableView {
                    Label("Can't reach mlx.app", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(e)
                } actions: {
                    Button("Try again") { Task { await store.resume() } }
                }
                .listRowBackground(Color.clear)
            } else {
                HStack { Spacer(); ProgressView(); Spacer() }.listRowBackground(Color.clear).padding(.vertical, 40)
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await store.refresh() }
        .navigationTitle(store.me?.account ?? "MLX")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Emblem(size: 28) }
        }
        .animation(.smooth(duration: 0.35), value: store.me)
    }
}

struct SummaryCard: View {
    let me: Me

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // side by side when there's room (iPhone), stacked in the narrower iPad sidebar
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center) {
                    SeatLine(me: me, onDark: true).fixedSize()
                    Spacer(minLength: 8)
                    miningPill.fixedSize()
                }
                VStack(alignment: .leading, spacing: 10) {
                    SeatLine(me: me, onDark: true)
                    miningPill
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("MINED TODAY").font(.caption.weight(.semibold)).opacity(0.7).kerning(0.6)
                LiveMined(me: me)
            }
            HStack(spacing: 0) {
                metric("Locked", "\(Amount.mlx(me.earning.locked)) MLX")
                divider
                metric("Mines up to", Amount.rate(maxRate)).padding(.leading, 12)
                divider
                metric("Unlocks after", "\(me.lockDays) days").padding(.leading, 12)
            }
            if me.throttled {
                Text("Short AI jobs now and then on a free seat. A dedicated seat matched to a Mac's chip mines up to 480× more.")
                    .font(.footnote).opacity(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.gradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.12)))
        .accessibilityElement(children: .combine)
    }

    /// What the wallet's Macs can mine an hour right now; with no Mac online, what its seats (or the free seat) allow.
    private var maxRate: Double {
        if let r = me.earning.perHourMax, r > 0 { return r }
        if me.dedicated { return me.nodes.compactMap(\.perHour).reduce(0, +) }
        return me.earning.freePerHour ?? 1.0 / 24
    }

    @ViewBuilder private var miningPill: some View {
        let state = me.live?.state ?? ""
        if me.mining || state == "paused" || state == "waiting" {
            HStack(spacing: 6) {
                Pulse(color: me.mining ? Brand.fullSpeed : Brand.throttled, active: me.mining)
                Text(me.mining ? "Mining" : state == "paused" ? "Paused" : "Waiting").font(.caption.weight(.semibold))
                if me.mining, let r = me.live?.rate, r > 0 {
                    Text("+" + String(Amount.rate(r * 3600).dropFirst())).font(.caption.monospacedDigit()).opacity(0.8)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.white.opacity(0.14), in: Capsule())
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }

    private var divider: some View { Rectangle().fill(.white.opacity(0.22)).frame(width: 1, height: 30) }

    private func metric(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k).font(.caption).opacity(0.7).lineLimit(1)
            Text(v).font(.callout.weight(.semibold).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MacRow: View {
    let mac: Me.Mac

    var body: some View {
        HStack(spacing: 12) {
            MacPicture(name: mac.picture, height: 42, dimmed: !mac.online)
            VStack(alignment: .leading, spacing: 3) {
                Text(mac.name).font(.body.weight(.semibold)).lineLimit(1)
                Text(mac.rowLine).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                StatusPill(status: mac.status)
                if mac.working, let t = mac.tps, t > 0 {
                    Text("\(Int(t.rounded())) tok/s").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct NoMacs: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No Macs yet").font(.body.weight(.semibold))
            Text("Install MLX Node on your Mac from mlx.app/download and link it to this wallet. It shows up here.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

/// "● MLX Mainnet · block 1,284": the network this app talks to, live.
struct NetworkLine: View {
    let me: Me
    var body: some View {
        HStack(spacing: 6) {
            Pulse(color: Brand.fullSpeed, active: true)
            Text(me.network?.name ?? "MLX Mainnet").fontWeight(.semibold)
            if let h = me.network?.height {
                Text("· block \(h.formatted())").monospacedDigit().contentTransition(.numericText())
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
}

/// iPad's page when nothing is selected: every Mac at a glance.
struct Overview: View {
    @EnvironmentObject private var store: Store
    private let cols = [GridItem(.adaptive(minimum: 260), spacing: 16)]

    var body: some View {
        ScrollView {
            if let me = store.me {
                LazyVGrid(columns: cols, spacing: 16) {
                    ForEach(me.macs) { mac in
                        NavigationLink(value: Route.mac(mac.pk)) {
                            Card { MacTile(mac: mac) }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                if me.macs.isEmpty { Card { NoMacs() }.padding(20) }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Your Macs")
        .navigationDestination(for: Route.self) { r in
            if case .mac(let pk) = r, let mac = store.me?.macs.first(where: { $0.pk == pk }) { MacDetailView(mac: mac) }
        }
    }
}

/// iPad overview tile: the Mac's drawing, its name and model, status and speed.
struct MacTile: View {
    let mac: Me.Mac
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                MacPicture(name: mac.picture, height: 72, dimmed: !mac.online)
                Spacer()
                StatusPill(status: mac.status)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(mac.name).font(.headline).lineLimit(1)
                Text(mac.rowLine).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
            }
            HStack {
                Label(mac.working && (mac.tps ?? 0) > 0 ? "\(Int((mac.tps ?? 0).rounded())) tok/s" : "–", systemImage: "speedometer")
                Spacer()
                if let r = mac.perHour, r > 0 { Text(Amount.rate(r)).monospacedDigit() }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .contentTransition(.numericText())
        }
    }
}
