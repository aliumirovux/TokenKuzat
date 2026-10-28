import SwiftUI
import AppKit

// Dizayn tizimi: shisha sirtlar (macOS 26+ — Liquid Glass, eskisida — material), yumshoq harakatlar,
// fon va kichik interaktiv effektlar. Butun ilova shu primitivlardan quriladi — uslub bir joyda.

// MARK: - Harakat

enum Motion {
    /// Asosiy: kartalar, ochilish-yopilish, tanlash
    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.86)
    /// Tez javob: hover, bosish
    static let snappy = Animation.spring(response: 0.26, dampingFraction: 0.9)
    /// Raqamlar va chiziqlar o'zgarishi
    static let smooth = Animation.easeInOut(duration: 0.45)

    /// Paydo bo'lish: biroz pastdan, xira va kichikroq holatdan
    static let appear = AnyTransition.opacity
        .combined(with: .scale(scale: 0.97, anchor: .top))
        .combined(with: .offset(y: 6))
}

// MARK: - Shisha

/// Shisha sirt. `tint` — yengil rang (holatni bildirish uchun), `interactive` — bosiladigan elementlar uchun.
struct GlassSurface<S: Shape>: ViewModifier {
    let shape: S
    var tint: Color? = nil
    var interactive = false
    var stroke: Color? = nil

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(glass, in: shape)
                .overlay(shape.stroke(stroke ?? .clear, lineWidth: 1.2))
        } else {
            content
                .background(.regularMaterial, in: shape)
                .background(shape.fill((tint ?? .clear).opacity(0.10)))
                .overlay(shape.stroke(stroke ?? Color.primary.opacity(0.08), lineWidth: 1))
                .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
        }
    }

    @available(macOS 26.0, *)
    private var glass: Glass {
        var g = Glass.regular
        if let tint { g = g.tint(tint.opacity(0.16)) }
        if interactive { g = g.interactive() }
        return g
    }
}

extension View {
    func glass(radius: CGFloat = 16, tint: Color? = nil, interactive: Bool = false, stroke: Color? = nil) -> some View {
        modifier(GlassSurface(shape: RoundedRectangle(cornerRadius: radius, style: .continuous),
                              tint: tint, interactive: interactive, stroke: stroke))
    }

    func glassCapsule(tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(GlassSurface(shape: Capsule(), tint: tint, interactive: interactive))
    }

    func glassCircle(tint: Color? = nil, interactive: Bool = false, stroke: Color? = nil) -> some View {
        modifier(GlassSurface(shape: Circle(), tint: tint, interactive: interactive, stroke: stroke))
    }

    /// Hover'da biroz ko'tariladi — bosiladigan kartalar uchun
    func hoverLift(_ amount: CGFloat = 1.012) -> some View {
        modifier(HoverLift(amount: amount))
    }

    /// Raqam o'zgarganda raqamlar «aylanib» almashadi
    func numericTransition(_ value: Double) -> some View {
        contentTransition(.numericText()).animation(Motion.smooth, value: value)
    }
}

private struct HoverLift: ViewModifier {
    let amount: CGFloat
    @State private var hover = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(hover ? amount : 1)
            .shadow(color: .black.opacity(hover ? 0.16 : 0), radius: hover ? 14 : 0, y: hover ? 6 : 0)
            .animation(Motion.snappy, value: hover)
            .onHover { hover = $0 }
    }
}

// MARK: - Fon

/// Oyna foni: sekin suzadigan, juda xira rangli dog'lar. Shisha sirtlar shu fonni «sindirib» ko'rsatadi.
/// Animatsiya Core Animation'da (repeatForever) — har kadrda qayta chizilmaydi, CPU deyarli sarflanmaydi.
struct AmbientBackground: View {
    @Environment(\.colorScheme) private var scheme
    @State private var drift = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let k: Double = scheme == .dark ? 0.22 : 0.16
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                blob(.blue, k, size: max(w, h) * 0.75)
                    .offset(x: drift ? -w * 0.18 : -w * 0.28, y: drift ? -h * 0.22 : -h * 0.30)
                blob(.purple, k * 0.8, size: max(w, h) * 0.6)
                    .offset(x: drift ? w * 0.30 : w * 0.22, y: drift ? h * 0.05 : -h * 0.06)
                blob(.teal, k * 0.7, size: max(w, h) * 0.55)
                    .offset(x: drift ? -w * 0.05 : w * 0.06, y: drift ? h * 0.36 : h * 0.28)
            }
            .frame(width: w, height: h)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) { drift = true }
        }
        .allowsHitTesting(false)
    }

    private func blob(_ c: Color, _ opacity: Double, size: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [c.opacity(opacity), c.opacity(0)], center: .center,
                                 startRadius: 0, endRadius: size / 2))
            .frame(width: size, height: size)
            .blur(radius: 40)
    }
}

// MARK: - Halqa ko'rsatkich

/// Limit halqasi: foiz, rang darajasi va ichida qisqa yozuv
struct RingGauge: View {
    let fraction: Double
    let title: String
    let value: String
    var caption: String? = nil
    var size: CGFloat = 92

    private var color: Color { fraction >= 0.9 ? .red : (fraction >= 0.7 ? .orange : .green) }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(Color.primary.opacity(0.08), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: min(1, max(0.002, fraction)))
                    .stroke(AngularGradient(colors: [color.opacity(0.6), color], center: .center,
                                            startAngle: .degrees(-90), endAngle: .degrees(270 * fraction)),
                            style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.35), radius: 6)
                    .animation(Motion.spring, value: fraction)
                VStack(spacing: 0) {
                    Text(value).font(.system(size: size * 0.22, weight: .semibold, design: .rounded))
                        .numericTransition(fraction)
                    Text(title).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(width: size, height: size)
            if let caption {
                Text(caption).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    .frame(width: size + 40)
            }
        }
    }
}
