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
                if mac.status == .harness { harnessBanner.transition(.opacity.combined(with: .move(edge: .top))) }
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
        VStack(spacing: 14) {
            MacPicture(name: mac.picture, height: 150, dimmed: !mac.online)
                .shadow(color: .black.opacity(0.18), radius: 18, y: 12)
                .padding(.top, 6)
            VStack(spacing: 6) {
                Text(mac.name).font(.title2.weight(.bold)).multilineTextAlignment(.center).lineLimit(2)
                Text(modelLine).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                HStack(spacing: 8) {
                    StatusPill(status: mac.status)
                    if let s = subtitle { Text(s).font(.footnote).foregroundStyle(.secondary).lineLimit(1) }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.regularMaterial)
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Brand.warm).opacity(mac.working ? 1 : 0.4))
        )
    }

    /// "MacBook Pro 14-inch (M5 Max, 2025) · 64 GB"
    private var modelLine: String {
        let inner = [mac.chip.isEmpty ? nil : mac.chip, mac.year.map { String($0) }].compactMap { $0 }.joined(separator: ", ")
        let model = inner.isEmpty ? mac.modelName : "\(mac.modelName) (\(inner))"
        return [model, mac.memoryGB > 0 ? "\(Int(mac.memoryGB)) GB" : nil].compactMap { $0 }.joined(separator: " · ")
    }

    private var subtitle: String? {
        if !mac.online, let seen = mac.seen {
            return "Last seen " + RelativeDateTimeFormatter().localizedString(for: Date(timeIntervalSince1970: seen / 1000), relativeTo: Date())
        }
        switch mac.status {
        case .ready: return mac.reason.hasPrefix("Free seat") ? "Waiting for the next AI job" : "Ready for the next AI job"
        case .waiting: return mac.reason.isEmpty ? nil : mac.reason
        case .working: return mac.state == "downloading" ? "Getting the model" : mac.state == "calibrating" ? "Measuring this Mac" : nil
        default: return nil
        }
    }

    private var harnessBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack").font(.title3).foregroundStyle(Brand.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text("Paused for MLX Harness").font(.subheadline.weight(.semibold))
                Text("MLX Harness is running AI on this Mac, so MLX Node stepped aside. It resumes by itself within an hour, or now with Resume.")
                    .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Brand.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        let pausedNow = mac.paused || mac.status == .harness
        let title = mac.status == .harness && !mac.paused ? "Resume now" : mac.manual ? (pausedNow ? "Start" : "Stop") : (pausedNow ? "Resume" : "Pause")
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
        .disabled(sending || !mac.online && !mac.paused)
        .sensoryFeedback(.impact(weight: .medium), trigger: store.sent[mac.pk])
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
                Label("Seat", systemImage: "cube.transparent").font(.caption).foregroundStyle(.secondary)
                if let c = mac.carries {
                    seatHeadline(seatTitle(c), full: true)
                    Text("AI jobs back to back. Mines up to \(Amount.rate(c.units * 8 / 24)) here.").font(.footnote).foregroundStyle(.secondary)
                    if c.units < c.full {
                        Text("This Mac's chip is a smaller class than the seat, so it mines less than the seat's full \(Amount.rate(c.full * 8 / 24)). A Mac of the seat's class mines it in full.")
                            .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                } else if store.me?.nodes.isEmpty ?? true {
                    seatHeadline("Free seat", full: false)
                    Text("Short AI jobs now and then. Mines up to \(Amount.rate(store.me?.earning.freePerHour ?? 1.0 / 24)) for the wallet, on its best Mac.")
                        .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(mac.online ? "Not carrying a seat" : "Offline").font(.headline)
                    Text("Each dedicated seat is carried by one Mac, the biggest seat by the biggest Mac. This Mac takes one over when it's free.")
                        .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// "Pro seat #128"
    private func seatTitle(_ c: Me.Mac.Carry) -> String {
        guard let id = c.id else { return "\(c.name) seat" }
        return "\(c.name) seat #\(id.formatted())"
    }

    private func seatHeadline(_ title: String, full: Bool) -> some View {
        let color = full ? Brand.fullSpeed : Brand.throttled
        return HStack(spacing: 7) {
            Circle().fill(color).frame(width: 7, height: 7)
            (Text(title) + Text(" · ").foregroundColor(.secondary) + Text(full ? "Full speed" : "Throttled").foregroundColor(color))
                .font(.headline)
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
                row("Model", mac.year.map { "\(mac.modelName), \($0)" } ?? mac.modelName)
                row("Chip", mac.chip.isEmpty ? "–" : "Apple \(mac.chip)")
                row("Memory", mac.memoryGB > 0 ? "\(Int(mac.memoryGB)) GB" : "–")
                row("System", mac.os.isEmpty ? "–" : mac.os)
                HStack {
                    Text("MLX Node").foregroundStyle(.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(mac.app.isEmpty ? "–" : mac.app)
                        if mac.outdated(latest: store.me?.node?.latest), let v = store.me?.node?.latest {
                            Text("\(v) is ready: Update in MLX Node").font(.caption).foregroundStyle(Brand.orange)
                        }
                    }
                }
                .font(.callout)
                if let p = mac.place { row("Near", p) }
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
