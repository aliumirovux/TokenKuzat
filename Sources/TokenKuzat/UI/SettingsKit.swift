import SwiftUI
import TokenKuzatCore

// Sozlamalar sahifasining qurilish bloklari: ikonli tablar, guruh kartasi, ikonli qator, holat belgisi.
// Form o'rniga o'zimizniki — o'ralgan izohli qatorlar balandligi to'g'ri hisoblanadi va bog'liq sozlamalar
// ota qator ostida ichkariga suriladi.

// MARK: - Tablar

/// Ikonli tablar (Safari / Xcode sozlamalari kabi): rangli plitka va nom, tanlangan tab ostida urg'u chizig'i
struct SettingsTabBar: View {
    @Binding var selection: SettingsTab
    @Namespace private var underline

    var body: some View {
        HStack(spacing: 4) {
            ForEach(SettingsTab.allCases) { t in
                let on = t == selection
                // Sahifa animatsiyasiz almashadi (eski va yangi sahifa ustma-ust chiqmasin) — faqat urg'u chizig'i suzadi
                Button {
                    selection = t
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: t.symbol)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(on ? Color.white : Color.secondary)
                            .frame(width: 30, height: 30)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(on ? t.tint : Brand.surface))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(on ? Color.clear : Brand.line, lineWidth: 1))
                        Text(t.title)
                            .font(.system(size: 12, weight: on ? .semibold : .regular))
                            .foregroundStyle(on ? Color.primary : Color.secondary)
                            .lineLimit(1).minimumScaleFactor(0.7)
                            // Kichraygan yorliq ham bir xil balandlikda — plitkalar bir chiziqda qoladi
                            .frame(height: 15)
                    }
                    .padding(.horizontal, 6).padding(.top, 2).padding(.bottom, 10)
                    .frame(minWidth: 64, maxWidth: 96)
                    .overlay(alignment: .bottom) {
                        if on {
                            Capsule().fill(Brand.accent).frame(height: 2).padding(.horizontal, 14)
                                .matchedGeometryEffect(id: "underline", in: underline)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .noFocusRing()
                .help(t.title)
                .accessibilityLabel(t.title)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
        .animation(Motion.snappy, value: selection)
        .padding(.horizontal, 20)
        .overlay(alignment: .bottom) { Rectangle().fill(Brand.line).frame(height: 1) }
    }
}

// MARK: - Guruh

/// Sarlavha, oq karta ichida qatorlar (oralarida ingichka chiziq) va pastda qisqa izoh; uzun tushuntirish «Batafsil» ichida
struct SettingsGroup<Content: View>: View {
    var title: String? = nil
    var footer: String? = nil
    var more: String? = nil
    /// «Xavfli» guruh — chegarasi qizg'ish
    var danger = false
    @ViewBuilder var content: () -> Content
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary).padding(.leading, 4)
            }
            _VariadicView.Tree(DividedRows()) { content() }
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Brand.surface))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(danger ? Brand.err.opacity(0.35) : Brand.line, lineWidth: 1))
            if footer != nil || more != nil {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        if let footer { Text(footer) }
                        if more != nil && !expanded {
                            Button(tr("Batafsil", "More")) { withAnimation(Motion.snappy) { expanded = true } }
                                .buttonStyle(.plain).foregroundStyle(Brand.accent)
                        }
                    }
                    if let more, expanded { Text(more).textSelection(.enabled) }
                }
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
            }
        }
    }
}

/// Qatorlar orasiga ingichka chiziq (birinchisidan oldin emas)
private struct DividedRows: _VariadicView_MultiViewRoot {
    func body(children: _VariadicView.Children) -> some View {
        let first = children.first?.id
        VStack(spacing: 0) {
            ForEach(children) { child in
                if child.id != first { Rectangle().fill(Brand.line).frame(height: 1) }
                child
            }
        }
    }
}

// MARK: - Qator

/// Ikon, nom, izoh va o'ng tomonda boshqaruv. `child` — ota sozlamaga bog'liq qator: ichkariga surilgan, ikonsiz.
/// O'chirilgan (`.disabled`) qatorning matni xiralashadi — ota kalit o'chiq ekani ko'rinadi.
struct SettingRow<Trailing: View, Below: View>: View {
    var symbol: String? = nil
    let title: String
    var subtitle: String? = nil
    var child = false
    var mono = false
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var below: () -> Below
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Group {
                if !child {
                    Image(systemName: symbol ?? "circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Brand.sunken))
                        .opacity(symbol == nil ? 0 : 1)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(mono ? .system(size: 12, design: .monospaced) : .system(size: 13, weight: child ? .regular : .medium))
                        .lineLimit(mono ? 1 : nil).truncationMode(.middle)
                    if let subtitle {
                        Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    below()
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(enabled ? 1 : 0.45)
            Spacer(minLength: 8)
            HStack(spacing: 8) { trailing() }.fixedSize()
        }
        .padding(.leading, child ? 56 : 16).padding(.trailing, 16).padding(.vertical, 10)
        .frame(minHeight: 52)
        .background(child ? Brand.sunken.opacity(0.5) : .clear)
    }
}

extension SettingRow where Below == EmptyView {
    init(symbol: String? = nil, title: String, subtitle: String? = nil, child: Bool = false, mono: Bool = false,
         @ViewBuilder trailing: @escaping () -> Trailing) {
        self.init(symbol: symbol, title: title, subtitle: subtitle, child: child, mono: mono, trailing: trailing, below: { EmptyView() })
    }
}

extension SettingRow where Trailing == EmptyView, Below == EmptyView {
    init(symbol: String? = nil, title: String, subtitle: String? = nil, child: Bool = false, mono: Bool = false) {
        self.init(symbol: symbol, title: title, subtitle: subtitle, child: child, mono: mono, trailing: { EmptyView() }, below: { EmptyView() })
    }
}

/// Kalitli qator — eng ko'p uchraydigan holat
struct ToggleRow<Extra: View>: View {
    var symbol: String? = nil
    let title: String
    var subtitle: String? = nil
    var child = false
    @Binding var isOn: Bool
    @ViewBuilder var extra: () -> Extra

    var body: some View {
        SettingRow(symbol: symbol, title: title, subtitle: subtitle, child: child) {
            extra()
            Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch).tint(Brand.accent)
        }
    }
}

extension ToggleRow where Extra == EmptyView {
    init(symbol: String? = nil, title: String, subtitle: String? = nil, child: Bool = false, isOn: Binding<Bool>) {
        self.init(symbol: symbol, title: title, subtitle: subtitle, child: child, isOn: isOn, extra: { EmptyView() })
    }
}

/// To'liq kenglikdagi qator (shkala, ogohlantirish) — ichkariga surilgan yoki oddiy
struct WideRow<Content: View>: View {
    var child = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, child ? 56 : 16).padding(.trailing, 16).padding(.vertical, 12)
            .background(child ? Brand.sunken.opacity(0.5) : .clear)
    }
}

// MARK: - Holat belgisi

/// Rangli kapsula va matn: «Ulangan», «Ishlayapti», «Ulanmagan» — holat faqat rang bilan emas, so'z bilan ham aytiladi
struct StateChip: View {
    enum Kind { case ok, warn, err, off }
    let text: String
    var kind: Kind = .off
    var symbol: String? = nil

    private var color: Color {
        switch kind {
        case .ok: return Brand.ok
        case .warn: return Brand.warn
        case .err: return Brand.err
        case .off: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol).font(.system(size: 10, weight: .bold)) }
            Text(text)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(color)
        .padding(.horizontal, 9).padding(.vertical, 3)
        .background(Capsule().fill(kind == .off ? Brand.sunken : color.opacity(0.13)))
        .overlay { if kind == .off { Capsule().strokeBorder(Brand.line, lineWidth: 1) } }
    }
}

/// Og'irlik yorlig'i: «javob ×5»
struct WeightTag: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 3) {
            Text(label).foregroundStyle(.secondary)
            Text(value).fontWeight(.semibold).monospacedDigit()
        }
        .font(.system(size: 12))
        .padding(.horizontal, 8).padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Brand.sunken))
    }
}
