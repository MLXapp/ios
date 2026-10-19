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
                            Label("Nodes", systemImage: "square.stack.3d.up.fill")
                            Spacer()
                            Text("\(me.nodes.count)").foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                    .accessibilityIdentifier("nodes")
                    NavigationLink(value: Route.settings) { Label("Settings", systemImage: "gearshape.fill") }
                        .accessibilityIdentifier("settings")
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
        VStack(alignment: .leading, spacing: 14) {
            Text("MINED TODAY").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.7)).kerning(0.6)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Amount.mlx(me.earning.today))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("MLX").font(.title3.weight(.semibold)).foregroundStyle(.white.opacity(0.8))
            }
            .foregroundStyle(.white)
            Text("≈ \(Amount.usd(me.earning.today, price: me.usdPerMlx)) at the network price")
                .font(.footnote).foregroundStyle(.white.opacity(0.75))
                .contentTransition(.numericText())
            HStack(spacing: 0) {
                metric("Locked, 18 months", Amount.mlx(me.earning.locked))
                Divider().frame(height: 30).overlay(.white.opacity(0.25))
                metric("Up to a day", Amount.mlx(me.earning.perDayMax, max: 1)).padding(.leading, 14)
            }
            if me.earning.free {
                Text("Your Macs mine at the free rate. A node matched to a Mac's chip multiplies what it earns, up to 320×.")
                    .font(.footnote).foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.gradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func metric(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k).font(.caption).foregroundStyle(.white.opacity(0.7))
            Text("\(v) MLX").font(.callout.weight(.semibold)).foregroundStyle(.white).contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MacRow: View {
    let mac: Me.Mac

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: mac.symbol)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(mac.online ? Brand.ink : .secondary)
                .frame(width: 44, height: 44)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(mac.name).font(.body.weight(.semibold)).lineLimit(1)
                Text([mac.chip, mac.memoryGB > 0 ? "\(Int(mac.memoryGB)) GB" : nil].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.footnote).foregroundStyle(.secondary).lineLimit(1)
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
            Text("Download MLX for Mac from mlx.app, open it on your Mac and link it to this wallet. It shows up here.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
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
                            Card { MacRow(mac: mac) }
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
