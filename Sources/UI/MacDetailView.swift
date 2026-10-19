import SwiftUI

struct MacDetailView: View {
    @EnvironmentObject private var store: Store
    let mac: Me.Mac
    @State private var draft = Me.Limits()
    @State private var editing = false
    @State private var sending = false

    private let grid = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                if store.sent[mac.pk] != nil || mac.pending > 0 { pendingBanner.transition(.opacity.combined(with: .move(edge: .top))) }
                control
                LazyVGrid(columns: grid, spacing: 12) {
                    stat("Speed", speed, "speedometer")
                    stat("Jobs today", mac.today.map { Amount.compact($0.jobs) } ?? "–", "checklist")
                    stat("AI tokens today", mac.today.map { Amount.compact($0.tokens) } ?? "–", "text.word.spacing")
                    stat("Checks passed", mac.today?.passRate.map { "\(Int(($0 * 100).rounded()))%" } ?? "–", "checkmark.seal")
                    stat("Temperature", thermal, "thermometer.medium")
                    stat("Power", mac.onAC ? "Plugged in" : "Battery", mac.onAC ? "powerplug.fill" : "battery.75")
                }
                carriesCard
                limitsCard
                aboutCard
            }
            .padding(16)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(mac.name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.refresh() }
        .animation(.smooth(duration: 0.35), value: mac)
        .animation(.smooth(duration: 0.35), value: store.sent[mac.pk])
        .onAppear { draft = mac.limits }
        .onChange(of: mac.limits) { _, l in if !editing { draft = l } }
    }

    // MARK: parts

    private var header: some View {
        HStack(spacing: 16) {
            Image(systemName: mac.symbol)
                .font(.system(size: 34, weight: .medium))
                .frame(width: 68, height: 68)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Text(mac.name).font(.title2.weight(.bold)).lineLimit(2)
                HStack(spacing: 8) {
                    StatusPill(status: mac.status)
                    Text(subtitle).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var subtitle: String {
        if !mac.online, let seen = mac.seen {
            return "Last seen " + RelativeDateTimeFormatter().localizedString(for: Date(timeIntervalSince1970: seen / 1000), relativeTo: Date())
        }
        if mac.status == .waiting, !mac.reason.isEmpty { return mac.reason }
        return [mac.chip, mac.memoryGB > 0 ? "\(Int(mac.memoryGB)) GB" : ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private var pendingBanner: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text(mac.online ? "Sent. Your Mac applies it within a minute." : "Sent. Your Mac applies it when it's back online.")
                .font(.footnote)
            Spacer()
        }
        .padding(12)
        .background(Brand.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var control: some View {
        let pausedNow = mac.paused
        let title = mac.manual ? (pausedNow ? "Start" : "Stop") : (pausedNow ? "Resume" : "Pause")
        return Button {
            sending = true
            Task {
                await store.send(mac, action: pausedNow ? "resume" : "pause")
                sending = false
            }
        } label: {
            HStack(spacing: 10) {
                if sending { ProgressView().tint(pausedNow ? Color(.systemBackground) : Brand.ink) } else { Image(systemName: pausedNow ? "play.fill" : (mac.manual ? "stop.fill" : "pause.fill")) }
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.borderedProminent)
        .tint(pausedNow ? Brand.ink : Color(.secondarySystemFill))
        .foregroundStyle(pausedNow ? Color(.systemBackground) : Brand.ink)
        .clipShape(Capsule())
        .disabled(sending)
        .accessibilityIdentifier("toggleRun")
    }

    private func stat(_ k: String, _ v: String, _ icon: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Label(k, systemImage: icon).font(.caption).foregroundStyle(.secondary)
                Text(v).font(.title3.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
            }
        }
    }

    private var speed: String {
        if mac.working, let t = mac.tps, t > 0 { return "\(Int(t.rounded())) tok/s" }
        if let c = mac.tokPerSec { return "\(Int(c.rounded())) tok/s max" }
        return "–"
    }

    private var thermal: String {
        switch mac.thermal {
        case "nominal": return "Cool"
        case "fair": return "Warm"
        case "serious": return "Hot"
        case "critical": return "Too hot"
        default: return "–"
        }
    }

    @ViewBuilder private var carriesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Label("Mining", systemImage: "cube.transparent").font(.caption).foregroundStyle(.secondary)
                if let c = mac.carries {
                    Text("Carries your \(c.name) node").font(.headline)
                    if c.units < c.full {
                        Text("This Mac's chip earns at a lower class than the node. A Mac of the node's class earns its full rate.")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Text("Earning the node's full rate, up to \(Amount.mlx(String(Int(c.units * 8 * 1_000_000)), max: 1)) MLX a day.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                } else if store.me?.nodes.isEmpty ?? true {
                    Text("Mining at the free rate").font(.headline)
                    Text("Up to 1 MLX a day. A node matched to this Mac's chip multiplies it.").font(.footnote).foregroundStyle(.secondary)
                } else {
                    Text(mac.online ? "Not carrying a node" : "Offline").font(.headline)
                    Text("Each node is carried by one Mac; the largest nodes go to the largest Macs.").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var limitsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Label("When MLX may work", systemImage: "slider.horizontal.3").font(.caption).foregroundStyle(.secondary)
                Stepper(value: Binding(get: { Int(draft.idleMinutes ?? 3) }, set: { draft.idleMinutes = Double($0); editing = true }), in: 0...60) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("After idle for")
                        Text((draft.idleMinutes ?? 3) == 0 ? "Off: start and stop it yourself" : "\(Int(draft.idleMinutes ?? 3)) min")
                            .font(.footnote).foregroundStyle(.secondary).contentTransition(.numericText())
                    }
                }
                Toggle("Only when plugged in", isOn: Binding(get: { draft.onlyOnAC ?? true }, set: { draft.onlyOnAC = $0; editing = true }))
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Memory MLX may use")
                        Spacer()
                        Text("\(Int(draft.memoryPct ?? 50))%").monospacedDigit().foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(get: { draft.memoryPct ?? 50 }, set: { draft.memoryPct = $0; editing = true }), in: 20...75, step: 5)
                }
                Picker("Hours", selection: Binding(get: { (draft.hoursFrom ?? 0) == (draft.hoursTo ?? 0) ? 0 : 1 }, set: { v in
                    editing = true
                    if v == 0 { draft.hoursFrom = 0; draft.hoursTo = 0 } else { draft.hoursFrom = 22; draft.hoursTo = 7 }
                })) {
                    Text("Any time").tag(0)
                    Text("Only at night").tag(1)
                }
                .pickerStyle(.segmented)
                if (draft.hoursFrom ?? 0) != (draft.hoursTo ?? 0) {
                    HStack {
                        Picker("From", selection: Binding(get: { Int(draft.hoursFrom ?? 22) }, set: { draft.hoursFrom = Double($0); editing = true })) {
                            ForEach(0..<24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
                        }
                        Spacer()
                        Picker("To", selection: Binding(get: { Int(draft.hoursTo ?? 7) }, set: { draft.hoursTo = Double($0); editing = true })) {
                            ForEach(0..<24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                HStack {
                    Text("Stop when the Mac gets")
                    Spacer()
                    Picker("Stop when the Mac gets", selection: Binding(get: { draft.maxThermal ?? "fair" }, set: { draft.maxThermal = $0; editing = true })) {
                        Text("Warm").tag("fair")
                        Text("Hot").tag("serious")
                    }
                    .labelsHidden()
                }
                if editing {
                    HStack {
                        Button("Cancel") {
                            draft = mac.limits
                            editing = false
                        }
                        Spacer()
                        Button {
                            Task {
                                var l: [String: Any] = [:]
                                if let v = draft.idleMinutes { l["idleMinutes"] = Int(v) }
                                if let v = draft.memoryPct { l["memoryPct"] = Int(v) }
                                if let v = draft.hoursFrom { l["hoursFrom"] = Int(v) }
                                if let v = draft.hoursTo { l["hoursTo"] = Int(v) }
                                if let v = draft.onlyOnAC { l["onlyOnAC"] = v }
                                if let v = draft.maxThermal { l["maxThermal"] = v }
                                await store.send(mac, action: "limits", limits: l)
                                editing = false
                            }
                        } label: {
                            Text("Send to \(mac.name)").fontWeight(.semibold).lineLimit(1)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Brand.orange)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.smooth(duration: 0.3), value: draft)
            .animation(.smooth(duration: 0.3), value: editing)
        }
    }

    private var aboutCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Label("This Mac", systemImage: "info.circle").font(.caption).foregroundStyle(.secondary)
                row("Chip", mac.chip.isEmpty ? "–" : "Apple \(mac.chip)")
                row("Memory", mac.memoryGB > 0 ? "\(Int(mac.memoryGB)) GB" : "–")
                row("System", mac.os.isEmpty ? "–" : mac.os)
                row("MLX app", mac.app.isEmpty ? "–" : mac.app)
                row("Linked", Date(timeIntervalSince1970: mac.linkedAt / 1000).formatted(date: .abbreviated, time: .omitted))
            }
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).foregroundStyle(.secondary)
            Spacer()
            Text(v).multilineTextAlignment(.trailing)
        }
        .font(.callout)
    }
}
