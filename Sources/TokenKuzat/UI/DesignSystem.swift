import SwiftUI
import AppKit

// Dizayn tizimi (v4 «Imzo»): tinch neytral sirtlar, bitta urg'u rangi, to'q siyoh rangli qahramon blok,
// katta displey raqamlar va maqsadli harakatlar. Shisha, nur va dekorativ gradientlar ishlatilmaydi —
// yumshoqlik radius, ingichka chegara va yengil soya bilan beriladi. Uslub bir joyda.

// MARK: - Ranglar

extension Color {
    /// Yorug' va qorong'i rejim uchun alohida qiymat
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { a in
            let hex = a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }
}

enum Brand {
    /// Yagona urg'u: tanlov, asosiy grafiklar, havolalar
    static let accent = Color(light: 0x6C5CE7, dark: 0x8F82FF)
    static let accentSoft = Color(light: 0xEFEDFD, dark: 0x272447)
    /// Qahramon blok (limit) — to'q siyoh
    static let ink = Color(light: 0x17152B, dark: 0x24204A)
    static let inkDim = Color(light: 0xA9A6C9, dark: 0xB3AEE0)
    static let inkFill = Color(light: 0x8F82FF, dark: 0xA79CFF)
    static let surface = Color(light: 0xFFFFFF, dark: 0x1F1F23)
    static let sunken = Color(light: 0xF4F4F6, dark: 0x18181B)
    static let canvas = Color(light: 0xF2F2F4, dark: 0x111113)
    static let line = Color(light: 0xE8E8EC, dark: 0x2C2C31)
    static let ok = Color(light: 0x17A35A, dark: 0x3DD68C)
    static let warn = Color(light: 0xC27C0E, dark: 0xF2B544)
    static let err = Color(light: 0xD93A2B, dark: 0xFF6E61)
    /// Loyiha monogrammalari uchun barqaror ranglar
    static let avatars: [Color] = [
        Color(light: 0x6C5CE7, dark: 0x7D6FF0), Color(light: 0x0E9F8E, dark: 0x16B3A0),
        Color(light: 0xE0731C, dark: 0xEC8432), Color(light: 0x2F7BE5, dark: 0x4A8FF0),
        Color(light: 0xD9467A, dark: 0xE65D8E), Color(light: 0x5B8C2A, dark: 0x6EA336),
    ]

    static func avatar(_ name: String) -> Color {
        let h = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFF_FFFF }
        return avatars[h % avatars.count]
    }
}

// MARK: - Harakat

enum Motion {
    /// Asosiy: kartalar, ochilish-yopilish, tanlash
    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.86)
    /// Tez javob: hover, bosish
    static let snappy = Animation.spring(response: 0.26, dampingFraction: 0.9)
    /// Raqamlar va chiziqlar o'zgarishi
    static let smooth = Animation.easeInOut(duration: 0.45)

    static let appear = AnyTransition.opacity
        .combined(with: .scale(scale: 0.97, anchor: .top))
        .combined(with: .offset(y: 6))
}

// MARK: - Sirt

/// Bir tekis sirt: oq/to'q kulrang fon, ingichka chegara, yengil soya. `tint` — holat uchun juda yengil rang.
struct Surface<S: Shape>: ViewModifier {
    let shape: S
    var tint: Color? = nil
    var interactive = false
    var stroke: Color? = nil
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background(shape.fill(Brand.surface))
            .background(shape.fill((tint ?? .clear).opacity(0.07)).allowsHitTesting(false))
            .overlay(shape.stroke(stroke ?? Brand.line, lineWidth: stroke == nil ? 1 : 1.5))
            .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.05), radius: 12, y: 4)
    }
}

extension View {
    func surface(radius: CGFloat = 16, tint: Color? = nil, interactive: Bool = false, stroke: Color? = nil) -> some View {
        modifier(Surface(shape: RoundedRectangle(cornerRadius: radius, style: .continuous),
                         tint: tint, interactive: interactive, stroke: stroke))
    }

    func surfaceCapsule(tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(Surface(shape: Capsule(), tint: tint, interactive: interactive))
    }

    func surfaceCircle(tint: Color? = nil, interactive: Bool = false, stroke: Color? = nil) -> some View {
        modifier(Surface(shape: Circle(), tint: tint, interactive: interactive, stroke: stroke))
    }

    /// Hover'da biroz ko'tariladi — bosiladigan kartalar uchun
    func hoverLift(_ amount: CGFloat = 1.008) -> some View {
        modifier(HoverLift(amount: amount))
    }

    /// Raqam o'zgarganda raqamlar «aylanib» almashadi
    func numericTransition(_ value: Double) -> some View {
        contentTransition(.numericText()).animation(Motion.smooth, value: value)
    }

    /// Sichqoncha bilan bosiladigan menyu tugmalarida ko'k fokus ramkasi chiqmasin
    @ViewBuilder
    func noFocusRing() -> some View {
        if #available(macOS 14.0, *) { focusEffectDisabled() } else { self }
    }

    /// Kichik bosh harf yorlig'i: «CLAUDE LIMITI»
    func eyebrow(_ color: Color = .secondary) -> some View {
        font(.system(size: 10.5, weight: .semibold)).tracking(0.7).foregroundStyle(color)
    }
}

private struct HoverLift: ViewModifier {
    let amount: CGFloat
    @State private var hover = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(hover ? amount : 1)
            .animation(Motion.snappy, value: hover)
            .onHover { hover = $0 }
    }
}

// MARK: - Displey raqam

/// Qahramon raqam: «86%» — yumaloq shrift, foiz belgisi yuqorida kichikroq
struct DisplayNumber: View {
    let value: Int
    var suffix = "%"
    var size: CGFloat = 84
    var color: Color = .primary

    var body: some View {
        HStack(alignment: .top, spacing: 2) {
            Text("\(value)")
                .font(.system(size: size, weight: .bold, design: .rounded))
                .tracking(-size * 0.04)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(Motion.smooth, value: value)
            Text(suffix)
                .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                .padding(.top, size * 0.08)
        }
        .foregroundStyle(color)
    }
}

// MARK: - Asbob plitasi

/// Asbob turi uchun to'q plitka (Terminal — qora, Fayllar — yashil-ko'k, MCP — to'q sariq…)
struct ToolTile: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).fill(color))
    }
}

/// Loyiha monogrammasi: rangli kvadratda birinchi harf
struct ProjectAvatar: View {
    let name: String
    var size: CGFloat = 32

    var body: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: size * 0.44, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous).fill(Brand.avatar(name)))
    }
}

// MARK: - Mini grafiklar

/// Ustunchali sparkline; oxirgi `highlight` tasi to'qroq
struct MiniBars: View {
    let values: [Double]
    var color: Color = Brand.accent
    var highlightLast = 6
    var spacing: CGFloat = 2

    var body: some View {
        let mx = max(values.max() ?? 1, 1)
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(color.opacity(i >= values.count - highlightLast ? 0.9 : 0.28))
                        .frame(height: max(3, geo.size.height * CGFloat(v / mx)))
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .animation(Motion.smooth, value: values)
    }
}
