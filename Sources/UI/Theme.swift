import SwiftUI

/// The MLX look: ink and orange, the brand gradient, the alpha-x emblem, SF Pro.
enum Brand {
    static let orange = Color("BrandOrange")
    static let ink = Color("BrandInk")
    static let gradient = LinearGradient(colors: [Color(red: 0.114, green: 0.114, blue: 0.122), Color(red: 0.941, green: 0.541, blue: 0)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
    /// Seat line dots, as in MLX Node: green at full speed, amber while throttled.
    static let fullSpeed = Color(red: 0.2, green: 0.78, blue: 0.35)
    static let throttled = Color(red: 1.0, green: 0.7, blue: 0.25)
    static let warm = LinearGradient(colors: [Color(red: 0.941, green: 0.541, blue: 0).opacity(0.18), .clear], startPoint: .topTrailing, endPoint: .bottomLeading)
}

/// The MDI alpha-x emblem inside its rounded square, filled with the brand gradient.
struct Emblem: View {
    var size: CGFloat = 44
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous).fill(Brand.gradient)
            XGlyph().fill(.white).frame(width: size * 0.26, height: size * 0.44)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The X of the emblem (MDI alpha-x: M9,7 L11,12 L9,17 H11 L12,14.5 L13,17 H15 L13,12 L15,7 H13 L12,9.5 L11,7 Z), in a 6×10 box.
struct XGlyph: Shape {
    func path(in r: CGRect) -> Path {
        let pts: [(CGFloat, CGFloat)] = [(0, 0), (2, 5), (0, 10), (2, 10), (3, 7.5), (4, 10), (6, 10), (4, 5), (6, 0), (4, 0), (3, 2.5), (2, 0)]
        var p = Path()
        for (i, (x, y)) in pts.enumerated() {
            let pt = CGPoint(x: r.minX + x / 6 * r.width, y: r.minY + y / 10 * r.height)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

/// "MLX" with the X at 70%.
struct Wordmark: View {
    var size: CGFloat = 22
    var body: some View {
        (Text("ML") + Text("X").foregroundColor(Brand.ink.opacity(0.7)))
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(Brand.ink)
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.primary.opacity(0.06)))
    }
}

struct StatusPill: View {
    let status: Me.Mac.Status
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
                .overlay(Circle().stroke(color.opacity(0.35), lineWidth: 4).scaleEffect(status == .working ? 1.6 : 1).opacity(status == .working ? 1 : 0))
            Text(label).font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.14), in: Capsule())
        .foregroundStyle(color)
        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: status == .working)
        .accessibilityElement(children: .combine)
    }

    var label: String {
        switch status {
        case .working: return "Working"
        case .ready: return "Ready"
        case .paused: return "Paused"
        case .stopped: return "Stopped"
        case .harness: return "Paused"
        case .waiting: return "Waiting"
        case .offline: return "Offline"
        }
    }

    var color: Color {
        switch status {
        case .working: return .green
        case .ready: return .teal
        case .paused, .stopped, .harness: return Brand.orange
        case .waiting: return .gray
        case .offline: return .red
        }
    }
}

/// A Mac's drawing (the same artwork as mlx.app and MLX World), crossfading when the model becomes known.
struct MacPicture: View {
    let name: String
    var height: CGFloat = 44
    var dimmed = false
    var body: some View {
        Image(name)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: height * 4 / 3, height: height)
            .saturation(dimmed ? 0 : 1)
            .opacity(dimmed ? 0.55 : 1)
            .id(name)
            .transition(.opacity)
            .animation(.smooth(duration: 0.5), value: name)
            .accessibilityHidden(true)
    }
}

/// "Free seat · Throttled" (amber) or "Pro seat #128 · Full speed" (green), as in MLX Node's earn card.
struct SeatLine: View {
    let me: Me
    var onDark = false
    var body: some View {
        let color = me.throttled ? Brand.throttled : Brand.fullSpeed
        HStack(spacing: 7) {
            Circle().fill(color).frame(width: 7, height: 7)
            (Text(title).foregroundColor(onDark ? .white : .primary)
             + Text(" · ").foregroundColor(onDark ? .white.opacity(0.6) : .secondary)
             + Text(me.throttled ? "Throttled" : "Full speed").foregroundColor(color))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        guard me.dedicated else { return "Free seat" }
        if me.nodes.count == 1, let s = me.nodes.first { return s.title }
        return "\(me.nodes.count) dedicated seats"
    }
}

/// The seat's glyph: a rounded square in the brand gradient with the seat's initial (C, P, U, N, L).
struct SeatGlyph: View {
    let seat: Me.Seat
    var size: CGFloat = 44
    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(Brand.gradient)
                .frame(width: size, height: size)
                .overlay(Text(String(seat.name.prefix(1))).font(.system(size: size * 0.42, weight: .bold, design: .rounded)).foregroundStyle(.white))
            if seat.latest ?? false {
                Circle().fill(Brand.orange).frame(width: size * 0.26, height: size * 0.26)
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                    .offset(x: size * 0.08, y: -size * 0.08)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Holds the number last drawn so a live count never steps back for a small correction (the wallet's LiveNumber).
final class LiveCounter {
    private var shown: Double = -1
    func value(_ target: Double) -> Double {
        if shown < 0 || target >= shown || shown - target > max(0.05, target * 0.02) { shown = target }
        return shown
    }
}

/// Mined MLX today, counted up per frame while a Mac works: settled today + this hour's unsettled MLX + its growth
/// since mlx.app measured it (capped at three minutes, so a stalled poll never runs away).
struct LiveMined: View {
    let me: Me
    var size: CGFloat = 40
    @State private var counter = LiveCounter()
    @State private var usdCounter = LiveCounter()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !me.mining)) { ctx in
            let v = counter.value(target(at: ctx.date))
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Amount.mlx6(v))
                        .font(.system(size: size, weight: .bold, design: .rounded).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("MLX").font(.title3.weight(.semibold)).opacity(0.8)
                }
                Text("≈ \(Amount.usd(usdCounter.value(v * me.usdPerMlx))) at the network price")
                    .font(.footnote.monospacedDigit()).opacity(0.75)
            }
        }
    }

    private func target(at d: Date) -> Double {
        let settled = (Double(me.earning.today) ?? 0) / 1_000_000
        guard let l = me.live else { return settled }
        let pending = (Double(l.pending) ?? 0) / 1_000_000
        let elapsed = min(180, max(0, d.timeIntervalSince1970 - l.at / 1000))
        return settled + pending + (me.mining ? l.rate * elapsed : 0)
    }
}

/// A small pulsing dot (working Macs, live mining).
struct Pulse: View {
    var color: Color = .green
    var active = true
    @State private var on = false
    var body: some View {
        Circle().fill(color).frame(width: 7, height: 7)
            .overlay(Circle().stroke(color.opacity(0.4), lineWidth: 4).scaleEffect(on ? 1.9 : 1).opacity(on ? 0 : (active ? 0.9 : 0)))
            .onAppear { if active { withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { on = true } } }
    }
}
