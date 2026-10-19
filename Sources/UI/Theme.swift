import SwiftUI

/// The MLX look: ink and orange, the brand gradient, the alpha-x emblem, SF Pro.
enum Brand {
    static let orange = Color("BrandOrange")
    static let ink = Color("BrandInk")
    static let gradient = LinearGradient(colors: [Color(red: 0.114, green: 0.114, blue: 0.122), Color(red: 0.941, green: 0.541, blue: 0)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
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
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.08)))
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
        case .waiting: return "Waiting"
        case .offline: return "Offline"
        }
    }

    var color: Color {
        switch status {
        case .working: return .green
        case .ready: return .teal
        case .paused, .stopped: return Brand.orange
        case .waiting: return .gray
        case .offline: return .red
        }
    }
}
