import SwiftUI

// Butun ilova uchun zamonaviy boshqaruvlar: tugma, matn maydoni, ± tugmalari.
// Tizimning ramkali (bezel) ko'rinishi o'rniga — yumshoq to'ldirilgan shakllar, ranglar ikki tema uchun aniq.

// MARK: - Tugma

/// `.primary` — asosiy amal (urg'u rangida), `.secondary` — oddiy amal (yengil kulrang), `.destructive` — xavfli amal (qizg'ish)
struct TKButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, destructive }
    var kind: Kind = .secondary
    var small = false

    func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration, kind: kind, small: small)
    }

    private struct StyledBody: View {
        let configuration: Configuration
        let kind: Kind
        let small: Bool
        @Environment(\.isEnabled) private var enabled
        @State private var hover = false

        // Qorong'i temada ham to'qroq urg'u — oq yozuv kontrasti 4.5:1 dan yuqori
        private static var primaryFill: Color { Color(light: 0x6C5CE7, dark: 0x6656DC) }
        private static var neutral: Color { Color(light: 0xEFEFF2, dark: 0x2E2E34) }
        private static var neutralHover: Color { Color(light: 0xE6E6EA, dark: 0x37373E) }

        private var fill: Color {
            switch kind {
            case .primary: return Self.primaryFill.opacity(hover ? 0.9 : 1)
            case .secondary: return hover ? Self.neutralHover : Self.neutral
            case .destructive: return Brand.err.opacity(hover ? 0.18 : 0.12)
            }
        }

        private var text: Color {
            switch kind {
            case .primary: return .white
            case .secondary: return .primary
            case .destructive: return Brand.err
            }
        }

        var body: some View {
            configuration.label
                .font(.system(size: small ? 12 : 13, weight: kind == .primary ? .semibold : .medium))
                .foregroundStyle(text)
                .lineLimit(1)
                .padding(.horizontal, small ? 10 : 12)
                .frame(height: small ? 24 : 28)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(fill))
                .overlay {
                    if kind == .secondary {
                        RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Brand.line, lineWidth: 1)
                    }
                }
                .shadow(color: kind == .primary ? Brand.accent.opacity(0.25) : .clear, radius: 3, y: 1)
                .contentShape(Rectangle())
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .opacity(enabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
                .onHover { hover = $0 && enabled }
                .animation(.easeOut(duration: 0.12), value: hover)
                .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
        }
    }
}

extension ButtonStyle where Self == TKButtonStyle {
    static var tkPrimary: TKButtonStyle { TKButtonStyle(kind: .primary) }
    static var tkSecondary: TKButtonStyle { TKButtonStyle(kind: .secondary) }
    static var tkDestructive: TKButtonStyle { TKButtonStyle(kind: .destructive) }
    static func tk(_ kind: TKButtonStyle.Kind, small: Bool = false) -> TKButtonStyle { TKButtonStyle(kind: kind, small: small) }
}

// MARK: - Matn maydoni

/// Botiq maydon: ingichka chegara, fokusda urg'u rangli halqa. `symbol` — chap tomondagi belgi (masalan, qidiruv uchun)
private struct TKField: ViewModifier {
    var symbol: String?
    var mono: Bool
    @FocusState private var focused: Bool
    @Environment(\.isEnabled) private var enabled

    private static var well: Color { Color(light: 0xFFFFFF, dark: 0x141417) }

    func body(content: Content) -> some View {
        HStack(spacing: 6) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            }
            content
                .textFieldStyle(.plain)
                .font(mono ? .system(size: 12.5, design: .monospaced) : .system(size: 13))
                .focused($focused)
        }
        .padding(.horizontal, 9)
        .frame(height: 28)
        // Matnni tizim o'zi xiralashtiradi — o'chiq maydonda faqat fon xiralashadi (ikki marta emas)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Self.well).opacity(enabled ? 1 : 0.45))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
            .strokeBorder(focused ? Brand.accent : Brand.line, lineWidth: focused ? 1.5 : 1))
        .shadow(color: focused ? Brand.accent.opacity(0.18) : .clear, radius: 3)
        // Belgi yoki chekka bosilganda ham fokus maydonga o'tadi
        .contentShape(Rectangle())
        .onTapGesture { if enabled { focused = true } }
        .animation(.easeOut(duration: 0.12), value: focused)
    }
}

extension View {
    /// TextField / SecureField'ni zamonaviy botiq maydonga o'raydi
    func tkField(symbol: String? = nil, mono: Bool = false) -> some View {
        modifier(TKField(symbol: symbol, mono: mono))
    }
}

// MARK: - ± tugmalari

/// Stepper o'rniga: yonma-yon «−» va «+» bir yo'lak ichida
struct TKStepper: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        HStack(spacing: 0) {
            button("minus", enabled: value > range.lowerBound) { value = max(range.lowerBound, value - step) }
            Rectangle().fill(Brand.line).frame(width: 1, height: 14)
            button("plus", enabled: value < range.upperBound) { value = min(range.upperBound, value + step) }
        }
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color(light: 0xEFEFF2, dark: 0x2E2E34)).opacity(enabled ? 1 : 0.45))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Brand.line, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        // Int() o'tkazishsiz — maydonga «1e400» yozilsa ham (inf) yiqilmaydi
        .accessibilityValue(value.formatted(.number.precision(.fractionLength(0...1))))
        .accessibilityAdjustableAction { dir in
            switch dir {
            case .increment: value = min(range.upperBound, value + step)
            case .decrement: value = max(range.lowerBound, value - step)
            @unknown default: break
            }
        }
    }

    private func button(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.primary)
        .disabled(!enabled)
    }
}
