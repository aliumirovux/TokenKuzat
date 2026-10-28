import SwiftUI

// Robot-yordamchi: Claude hozir nima qilayotganini jonli ko'rsatadi. Oddiy shakllardan chizilgan:
// antenna (yonib turadi), bosh-ekran (ko'zlar qisiladi, u yoq-bu yoqqa qaraydi), tana va ikki qo'l.

struct RobotView: View {
    enum Mood: Equatable {
        /// Asbob ishlatyapti — qo'llar harakatda, antenna yonadi
        case working(String)
        /// Model o'ylayapti — ko'zlar u yoq-bu yoqqa yuradi
        case thinking
        /// Ish tugagan — ko'zlar yumiq, «z z»
        case sleeping
        /// Ruxsat kutyapti — qo'l ko'tarilgan
        case waiting
    }

    let mood: Mood
    var color: Color = Brand.accent
    var size: CGFloat = 46
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { ctx in
            let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
            VStack(spacing: 4) {
                bubble(t)
                robot(t)
            }
        }
        .allowsHitTesting(false)
        .accessibilityLabel(label)
    }

    private var label: String {
        switch mood {
        case .working(let s): return "Robot ishlayapti: \(s)"
        case .thinking: return "Robot o'ylayapti"
        case .sleeping: return "Robot dam olyapti"
        case .waiting: return "Robot ruxsat kutyapti"
        }
    }

    private var tint: Color {
        switch mood {
        case .working: return Brand.ok
        case .thinking: return Brand.inkFill
        case .sleeping: return .secondary
        case .waiting: return Brand.warn
        }
    }

    // MARK: Gap pufagi

    @ViewBuilder
    private func bubble(_ t: Double) -> some View {
        let text: String = {
            switch mood {
            case .working(let s): return s + "…"
            case .thinking:
                let n = Int(t * 2.5) % 4
                return "o'ylayapti" + String(repeating: ".", count: n)
            case .sleeping: return Int(t * 1.2) % 2 == 0 ? "z z" : "z Z"
            case .waiting: return "ruxsat kerak"
            }
        }()
        Text(text)
            .font(.system(size: size * 0.24, weight: .semibold, design: .rounded))
            .foregroundStyle(mood == .sleeping ? Color.secondary : tint)
            .lineLimit(1).fixedSize()
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Capsule().fill(Brand.surface))
            .overlay(Capsule().stroke(tint.opacity(0.45)))
            .frame(minWidth: 130)
    }

    // MARK: Robot

    private func robot(_ t: Double) -> some View {
        let s = size
        let bob: CGFloat = {
            switch mood {
            case .working: return CGFloat(sin(t * 9)) * s * 0.03
            case .thinking: return CGFloat(sin(t * 2.4)) * s * 0.05
            case .sleeping: return CGFloat(sin(t * 1.2)) * s * 0.025
            case .waiting: return CGFloat(abs(sin(t * 4))) * -s * 0.06
            }
        }()
        return ZStack {
            // Antenna: tayoqcha va yonib turuvchi uch
            VStack(spacing: 0) {
                Circle().fill(tint)
                    .frame(width: s * 0.13, height: s * 0.13)
                    .shadow(color: tint.opacity(glow(t)), radius: s * 0.12)
                    .opacity(mood == .sleeping ? 0.4 : 0.6 + 0.4 * glow(t))
                Rectangle().fill(Brand.line).frame(width: s * 0.035, height: s * 0.12)
            }
            .offset(y: -s * 0.47)

            // Qo'llar
            arm(t, left: true).offset(x: -s * 0.36, y: s * 0.24)
            arm(t, left: false).offset(x: s * 0.36, y: s * 0.24)

            // Tana
            RoundedRectangle(cornerRadius: s * 0.1, style: .continuous)
                .fill(Brand.surface)
                .overlay(RoundedRectangle(cornerRadius: s * 0.1, style: .continuous).stroke(color.opacity(0.7), lineWidth: 1.4))
                .overlay(Circle().fill(tint.opacity(0.5 + 0.5 * glow(t))).frame(width: s * 0.09, height: s * 0.09))
                .frame(width: s * 0.44, height: s * 0.26)
                .offset(y: s * 0.27)

            // Bosh-ekran
            RoundedRectangle(cornerRadius: s * 0.16, style: .continuous)
                .fill(Brand.surface)
                .overlay(RoundedRectangle(cornerRadius: s * 0.16, style: .continuous).stroke(color, lineWidth: 1.6))
                .overlay(face(t).padding(s * 0.08))
                .frame(width: s * 0.7, height: s * 0.5)
                .offset(y: -s * 0.08)
        }
        .frame(width: s, height: s * 1.1)
        .offset(y: bob)
    }

    /// Antenna nuri: 0…1
    private func glow(_ t: Double) -> Double {
        switch mood {
        case .working: return 0.5 + 0.5 * sin(t * 8)
        case .thinking: return 0.5 + 0.5 * sin(t * 3)
        case .waiting: return Int(t * 2) % 2 == 0 ? 1 : 0.2
        case .sleeping: return 0.1
        }
    }

    private func face(_ t: Double) -> some View {
        let s = size
        // Ko'z qisish: har ~3,2 s da 0,15 s
        let blink = (t.truncatingRemainder(dividingBy: 3.2)) < 0.15
        let look: CGFloat = {
            switch mood {
            case .thinking: return CGFloat(sin(t * 1.8)) * s * 0.06
            case .working: return s * 0.03
            default: return 0
            }
        }()
        return RoundedRectangle(cornerRadius: s * 0.09, style: .continuous)
            .fill(Brand.ink)
            .overlay {
                HStack(spacing: s * 0.13) {
                    eye(closed: mood == .sleeping || blink)
                    eye(closed: mood == .sleeping || blink)
                }
                .offset(x: look)
            }
    }

    private func eye(closed: Bool) -> some View {
        let s = size
        return Capsule()
            .fill(tint == .secondary ? Brand.inkDim : tint)
            .frame(width: s * 0.09, height: closed ? s * 0.025 : s * 0.12)
            .shadow(color: tint.opacity(0.6), radius: closed ? 0 : 2)
    }

    private func arm(_ t: Double, left: Bool) -> some View {
        let s = size
        let angle: Double = {
            switch mood {
            case .working: return (left ? 1 : -1) * (20 + 25 * sin(t * 12 + (left ? 0 : .pi)))
            case .waiting: return left ? 15 : -150 + 12 * sin(t * 6)
            case .thinking: return (left ? 1 : -1) * 15
            case .sleeping: return (left ? 1 : -1) * 5
            }
        }()
        return Capsule()
            .fill(color.opacity(0.75))
            .frame(width: s * 0.07, height: s * 0.24)
            .rotationEffect(.degrees(angle), anchor: .top)
    }
}
