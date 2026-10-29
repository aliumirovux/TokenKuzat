import SwiftUI
import TokenKuzatCore

// Robot-yordamchi: Claude hozir nima qilayotganini xarakter bilan ko'rsatadi. Har bir vazifada — o'z harakati,
// qo'lidagi buyumi va yuz ifodasi. Oddiy shakllardan chizilgan: antenna, bosh-ekran (ko'zlar, og'iz), tana, qo'llar.

struct RobotView: View {
    enum Action: Equatable {
        case typing(String)       // Terminal — noutbukda yozadi
        case reading(String)      // fayl o'qish — lupa bilan
        case writing(String)      // fayl o'zgartirish — qalam bilan
        case browsing(String)     // internet — globus va to'lqinlar
        case plugging(String)     // tashqi xizmat — vilka va uchqun
        case delegating(String)   // yordamchi agent — qo'l silkitib topshiradi
        case tinkering(String)    // boshqa asbob — kalit bilan
        case thinking             // o'ylayapti — lampochka
        case answering            // javob yozyapti — gap pufagi
        case waiting              // ruxsat kutyapti — qo'l ko'tarilgan
        case error                // xato — titraydi, ter tomchisi
        case greeting             // yangi so'rov — «!» va qo'l silkitish
        case celebrating          // ish tugadi — sakraydi, yulduzchalar
        case sleeping             // tinch — «z z»
        case watching             // nazorat — durbin bilan kuzatadi (tinch paytda patrul)
        case hello                // bosilganda — «salom!»
    }

    let action: Action
    var color: Color = Brand.accent
    var size: CGFloat = 58
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Pref.lightMode) private var lightMode = false

    var body: some View {
        let still = reduceMotion || lightMode || Power.saving
        // 20 kadr/s — mayda harakatlar uchun yetarli; tinch holatda (uxlash, kuzatish) — 8 kadr/s, sekin harakatlar
        // shunda ham silliq. Shakl GPU'da chiziladi (drawingGroup)
        let calm = action == .sleeping || action == .watching
        TimelineView(.animation(minimumInterval: calm ? 1.0 / 8 : 1.0 / 20, paused: still)) { ctx in
            let t = still ? 0 : ctx.date.timeIntervalSinceReferenceDate
            VStack(spacing: 4) {
                caption(t)
                figure(t).padding(8).drawingGroup().padding(-8)
            }
        }
        .allowsHitTesting(false)
        .accessibilityLabel("Robot: " + text(0))
        .id(kindKey)            // holat almashganda yangi harakat boshidan
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }

    // MARK: Holat xususiyatlari

    private var kindKey: String {
        switch action {
        case .typing: return "typing"
        case .reading: return "reading"
        case .writing: return "writing"
        case .browsing: return "browsing"
        case .plugging: return "plugging"
        case .delegating: return "delegating"
        case .tinkering: return "tinkering"
        case .thinking: return "thinking"
        case .answering: return "answering"
        case .waiting: return "waiting"
        case .error: return "error"
        case .greeting: return "greeting"
        case .celebrating: return "celebrating"
        case .sleeping: return "sleeping"
        case .watching: return "watching"
        case .hello: return "hello"
        }
    }

    private var tint: Color {
        switch action {
        case .typing, .reading, .writing, .browsing, .plugging, .delegating, .tinkering: return Brand.ok
        case .thinking, .answering: return Brand.inkFill
        case .waiting: return Brand.warn
        case .error: return Brand.err
        case .greeting: return Brand.accent
        case .celebrating: return Color(light: 0xE0A21C, dark: 0xF2B544)
        case .sleeping: return .secondary
        case .watching: return Color(light: 0x2F7BE5, dark: 0x4A8FF0)
        case .hello: return Brand.accent
        }
    }

    /// Davom etayotgan ishlar — oxirida sakrovchi nuqtalar
    private var ongoing: Bool {
        switch action {
        case .waiting, .error, .greeting, .celebrating, .sleeping, .hello: return false
        default: return true
        }
    }

    /// Gap pufagidagi kichik belgi
    private var symbol: String {
        switch action {
        case .typing: return "terminal.fill"
        case .reading: return "eye.fill"
        case .writing: return "pencil"
        case .browsing: return "globe"
        case .plugging: return "powerplug.fill"
        case .delegating: return "person.2.fill"
        case .tinkering: return "wrench.adjustable.fill"
        case .thinking: return "lightbulb.fill"
        case .answering: return "text.bubble.fill"
        case .waiting: return "hand.raised.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .greeting: return "sparkles"
        case .celebrating: return "checkmark.seal.fill"
        case .sleeping: return "moon.zzz.fill"
        case .watching: return "binoculars.fill"
        case .hello: return "hand.wave.fill"
        }
    }

    private func text(_ t: Double) -> String {
        switch action {
        case .typing(let s), .reading(let s), .writing(let s), .browsing(let s), .plugging(let s),
             .delegating(let s), .tinkering(let s):
            return s
        case .thinking: return tr("o'ylayapti", "thinking")
        case .answering: return tr("javob yozyapti", "answering")
        case .waiting: return tr("ruxsat kerak", "need permission")
        case .error: return tr("voy, xato!", "oops, error!")
        case .greeting: return tr("yangi vazifa!", "new task!")
        case .celebrating: return tr("tayyor!", "done!")
        case .sleeping: return Int(t * 1.2) % 2 == 0 ? "z z" : "z Z"
        case .watching: return tr("nazorat qilyapman", "keeping watch")
        case .hello: return tr("salom!", "hello!")
        }
    }

    /// Gap pufagi: robotga qaragan dum, belgi, matn va (davom etayotgan ishda) sakrovchi uch nuqta
    private func caption(_ t: Double) -> some View {
        let c = tint == .secondary ? Brand.inkDim : tint
        return HStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: size * 0.17, weight: .bold))
            Text(text(t)).font(.system(size: size * 0.2, weight: .semibold, design: .rounded))
                .lineLimit(1).truncationMode(.middle).frame(maxWidth: size * 2.6)
            if ongoing {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle().frame(width: size * 0.055, height: size * 0.055)
                            .offset(y: -CGFloat(max(0, sin(t * 7 - Double(i) * 0.7))) * size * 0.05)
                    }
                }
                .padding(.leading, 1)
            }
        }
        .foregroundStyle(c)
        .fixedSize()
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(SpeechBubble(tail: size * 0.09).fill(Brand.surface))
        .background(SpeechBubble(tail: size * 0.09).fill(c.opacity(0.14)))
        .overlay(SpeechBubble(tail: size * 0.09).stroke(c.opacity(0.5), lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        .padding(.bottom, size * 0.09)
    }

    // MARK: Gavda

    private func figure(_ t: Double) -> some View {
        let s = size
        let shell = LinearGradient(colors: [Color(light: 0xFFFFFF, dark: 0x34343C), Color(light: 0xE9E9F0, dark: 0x1E1E24)],
                                   startPoint: .top, endPoint: .bottom)
        return ZStack {
            // Yerdagi soya: robot ko'tarilsa — kichrayadi va xiralashadi
            Ellipse().fill(.black.opacity(0.28 - Double(-bob(t) / s) * 0.6))
                .frame(width: s * (0.62 + bob(t) / s * 0.8), height: s * 0.1)
                .blur(radius: 2)
                .offset(y: s * 0.52 - bob(t))
            effects(t)
            // Antenna: yumaloq uchli tayoqcha, uchida yorug'lik
            VStack(spacing: 0) {
                Circle().fill(RadialGradient(colors: [.white.opacity(0.9), tint], center: .init(x: 0.35, y: 0.35),
                                             startRadius: 0, endRadius: s * 0.08))
                    .frame(width: s * 0.13, height: s * 0.13)
                    .shadow(color: tint.opacity(glow(t) * 0.9), radius: s * 0.1)
                    .opacity(action == .sleeping ? 0.45 : 0.6 + 0.4 * glow(t))
                Capsule().fill(color.opacity(0.55)).frame(width: s * 0.04, height: s * 0.11)
            }
            .offset(y: -s * 0.46)
            .rotationEffect(.degrees(antennaTilt(t)), anchor: .bottom)

            arm(t, left: true).offset(x: -s * 0.35, y: s * 0.2)
            arm(t, left: false).offset(x: s * 0.35, y: s * 0.2)

            // Tana: ko'krakda kichik ekran — holat chirog'i
            RoundedRectangle(cornerRadius: s * 0.12, style: .continuous)
                .fill(shell)
                .overlay(RoundedRectangle(cornerRadius: s * 0.12, style: .continuous).stroke(color.opacity(0.75), lineWidth: 1.4))
                .overlay(
                    RoundedRectangle(cornerRadius: s * 0.03, style: .continuous).fill(Brand.ink)
                        .overlay(Capsule().fill(tint.opacity(0.5 + 0.5 * glow(t)))
                            .frame(width: s * (0.06 + 0.08 * glow(t)), height: s * 0.035))
                        .frame(width: s * 0.2, height: s * 0.08)
                )
                .frame(width: s * 0.46, height: s * 0.27)
                .offset(y: s * 0.27)

            // Bosh: gradientli qobiq, tepasida yaltiroq, ichida ekran-yuz
            RoundedRectangle(cornerRadius: s * 0.17, style: .continuous)
                .fill(shell)
                .overlay(alignment: .top) {
                    Capsule().fill(.white.opacity(0.18)).frame(width: s * 0.4, height: s * 0.04).offset(y: s * 0.03)
                }
                .overlay(RoundedRectangle(cornerRadius: s * 0.17, style: .continuous).stroke(color, lineWidth: 1.7))
                .overlay(face(t).padding(s * 0.075))
                .shadow(color: .black.opacity(0.22), radius: 3, y: 2)
                .frame(width: s * 0.7, height: s * 0.5)
                .offset(y: -s * 0.08)
                .rotationEffect(.degrees(headTilt(t)))

            prop(t)
        }
        .frame(width: s * 1.5, height: s * 1.15)
        .offset(x: shake(t), y: bob(t))
        .scaleEffect(squash(t), anchor: .bottom)
    }

    private func bob(_ t: Double) -> CGFloat {
        let s = size
        switch action {
        case .typing: return CGFloat(sin(t * 14)) * s * 0.015
        case .celebrating: return -CGFloat(abs(sin(t * 5))) * s * 0.22
        case .greeting: return -CGFloat(abs(sin(t * 6))) * s * 0.08
        case .sleeping: return CGFloat(sin(t * 1.2)) * s * 0.02
        case .hello: return -CGFloat(abs(sin(t * 7))) * s * 0.16
        case .error: return 0
        default: return CGFloat(sin(t * 2.4)) * s * 0.035
        }
    }

    private func shake(_ t: Double) -> CGFloat {
        action == .error ? CGFloat(sin(t * 40)) * size * 0.03 * CGFloat(abs(sin(t * 1.5))) : 0
    }

    /// Sakrashda qo'nishdagi «yassilanish»
    private func squash(_ t: Double) -> CGFloat {
        guard action == .celebrating else { return 1 }
        let k = abs(sin(t * 5))
        return k < 0.15 ? 0.94 : 1
    }

    private func headTilt(_ t: Double) -> Double {
        switch action {
        case .thinking: return 8 + 3 * sin(t * 1.5)
        case .reading: return -4
        case .writing: return 5
        case .delegating, .greeting: return 6 * sin(t * 3)
        case .sleeping: return 10
        case .watching: return 6 * sin(t * 0.9)
        case .waiting: return -6
        default: return 0
        }
    }

    private func antennaTilt(_ t: Double) -> Double {
        switch action {
        case .browsing: return 12 * sin(t * 4)
        case .error: return 20 * sin(t * 30)
        case .celebrating: return 15 * sin(t * 10)
        default: return 3 * sin(t * 2)
        }
    }

    /// Antenna nuri: 0…1
    private func glow(_ t: Double) -> Double {
        switch action {
        case .typing, .plugging: return 0.5 + 0.5 * sin(t * 10)
        case .thinking: return 0.5 + 0.5 * sin(t * 3)
        case .waiting, .error: return Int(t * 2.5) % 2 == 0 ? 1 : 0.15
        case .sleeping: return 0.1
        case .celebrating: return 1
        default: return 0.5 + 0.5 * sin(t * 5)
        }
    }

    // MARK: Yuz

    private enum Eye: Equatable { case open, closed, happy, wide, cross, focused }

    private func face(_ t: Double) -> some View {
        let s = size
        let blink = t.truncatingRemainder(dividingBy: 3.4) < 0.14
        let eye: Eye = {
            switch action {
            case .sleeping: return .closed
            case .hello: return .happy
            case .celebrating, .delegating, .writing: return .happy
            case .greeting, .waiting: return blink ? .closed : .wide
            case .error: return .cross
            case .typing, .plugging: return blink ? .closed : .focused
            default: return blink ? .closed : .open
            }
        }()
        // Qayerga qaraydi: o'qiyotganda — qatorlar bo'ylab, o'ylayotganda — tepaga-yonga
        let look: CGSize = {
            switch action {
            case .reading: return CGSize(width: CGFloat((t.truncatingRemainder(dividingBy: 1.6)) / 1.6 - 0.5) * s * 0.16, height: s * 0.02)
            case .thinking: return CGSize(width: CGFloat(sin(t * 1.4)) * s * 0.06, height: -s * 0.03)
            case .typing: return CGSize(width: 0, height: s * 0.03)
            case .browsing: return CGSize(width: CGFloat(sin(t * 2)) * s * 0.07, height: 0)
            case .watching: return CGSize(width: CGFloat(sin(t * 0.9)) * s * 0.08, height: -s * 0.01)
            default: return .zero
            }
        }()
        return RoundedRectangle(cornerRadius: s * 0.09, style: .continuous)
            .fill(Brand.ink)
            .overlay {
                VStack(spacing: s * 0.035) {
                    HStack(spacing: s * 0.12) {
                        eyeView(eye)
                        eyeView(eye)
                    }
                    .offset(look)
                    mouth(t)
                }
                .overlay {
                    if eye == .happy {
                        // Xursandlikda yonoqlar qizaradi
                        HStack(spacing: s * 0.3) {
                            Ellipse().fill(Color(light: 0xF06A8A, dark: 0xFF7A9A).opacity(0.45)).frame(width: s * 0.08, height: s * 0.04)
                            Ellipse().fill(Color(light: 0xF06A8A, dark: 0xFF7A9A).opacity(0.45)).frame(width: s * 0.08, height: s * 0.04)
                        }
                        .offset(y: s * 0.04)
                    }
                }
            }
    }

    @ViewBuilder
    private func eyeView(_ e: Eye) -> some View {
        let s = size
        let c = tint == .secondary ? Brand.inkDim : tint
        switch e {
        case .open:
            Capsule().fill(c).frame(width: s * 0.085, height: s * 0.11).shadow(color: c.opacity(0.7), radius: 3)
                .overlay(alignment: .topTrailing) { Circle().fill(.white.opacity(0.8)).frame(width: s * 0.025).offset(x: -s * 0.012, y: s * 0.015) }
        case .focused:
            Capsule().fill(c).frame(width: s * 0.1, height: s * 0.06).shadow(color: c.opacity(0.6), radius: 2)
        case .closed:
            Capsule().fill(c).frame(width: s * 0.09, height: s * 0.022)
        case .wide:
            Circle().stroke(c, lineWidth: 1.6).frame(width: s * 0.12, height: s * 0.12)
                .overlay(Circle().fill(c).frame(width: s * 0.05, height: s * 0.05))
        case .happy:
            Arc(up: true).stroke(c, style: StrokeStyle(lineWidth: 2, lineCap: .round)).frame(width: s * 0.1, height: s * 0.06)
        case .cross:
            ZStack {
                Capsule().fill(c).frame(width: s * 0.11, height: s * 0.025).rotationEffect(.degrees(45))
                Capsule().fill(c).frame(width: s * 0.11, height: s * 0.025).rotationEffect(.degrees(-45))
            }
        }
    }

    @ViewBuilder
    private func mouth(_ t: Double) -> some View {
        let s = size
        let c = (tint == .secondary ? Brand.inkDim : tint).opacity(0.85)
        switch action {
        case .celebrating, .delegating, .greeting, .hello:
            Arc(up: false).fill(c).frame(width: s * 0.14, height: s * 0.06)
        case .error:
            Arc(up: true).stroke(c, style: StrokeStyle(lineWidth: 1.6, lineCap: .round)).frame(width: s * 0.12, height: s * 0.04)
        case .answering:
            // Gapiryapti: og'iz ochilib-yopiladi
            Capsule().fill(c).frame(width: s * 0.1, height: s * (0.015 + 0.04 * abs(sin(t * 9))))
        case .waiting:
            Circle().stroke(c, lineWidth: 1.4).frame(width: s * 0.05, height: s * 0.05)
        case .sleeping:
            Capsule().fill(c.opacity(0.5)).frame(width: s * 0.06, height: s * 0.015)
        default:
            Capsule().fill(c).frame(width: s * 0.09, height: s * 0.016)
        }
    }

    // MARK: Qo'llar

    private func arm(_ t: Double, left: Bool) -> some View {
        let s = size
        let side: Double = left ? 1 : -1
        let angle: Double = {
            switch action {
            case .typing: return side * (35 + 18 * sin(t * 16 + (left ? 0 : .pi)))
            case .writing: return left ? 10 : -55 + 10 * sin(t * 8)
            case .reading: return left ? 10 : -60
            case .browsing: return left ? 10 : -70 + 6 * sin(t * 3)
            case .plugging: return left ? 30 + 8 * sin(t * 10) : -40 + 8 * sin(t * 10)
            case .delegating: return left ? 10 : -140 + 25 * sin(t * 7)
            case .tinkering: return left ? 15 : -50 + 30 * sin(t * 9)
            case .thinking: return left ? 12 : -125
            case .answering: return side * (15 + 10 * sin(t * 4))
            case .waiting: return left ? 12 : -165 + 8 * sin(t * 5)
            case .error: return side * (60 + 10 * sin(t * 25))
            case .greeting: return left ? 15 : -150 + 30 * sin(t * 9)
            case .celebrating: return side * (150 + 15 * sin(t * 10))
            case .sleeping: return side * 4
            case .watching: return side * -150 + side * 6 * sin(t * 0.9)
            case .hello: return left ? 15 : -155 + 35 * sin(t * 11)
            }
        }()
        return VStack(spacing: -s * 0.02) {
            Capsule().fill(color.opacity(0.75)).frame(width: s * 0.07, height: s * 0.2)
            Circle().fill(color).frame(width: s * 0.1, height: s * 0.1)
        }
        .frame(height: s * 0.28, alignment: .top)
        .rotationEffect(.degrees(angle), anchor: .top)
    }

    // MARK: Buyumlar va effektlar

    /// Qo'ldagi buyum (vazifaga mos)
    @ViewBuilder
    private func prop(_ t: Double) -> some View {
        let s = size
        switch action {
        case .typing:
            // Noutbuk tananing oldida, ekrani yonib-o'chadi
            ZStack {
                Image(systemName: "laptopcomputer").font(.system(size: s * 0.36, weight: .medium)).foregroundStyle(Brand.inkDim)
                RoundedRectangle(cornerRadius: 1).fill(Brand.ok.opacity(0.35 + 0.35 * sin(t * 6)))
                    .frame(width: s * 0.2, height: s * 0.09).offset(y: -s * 0.04)
            }
            .offset(y: s * 0.42)
        case .reading:
            Image(systemName: "magnifyingglass").font(.system(size: s * 0.24, weight: .bold)).foregroundStyle(tint)
                .offset(x: s * 0.5 + CGFloat(sin(t * 2)) * s * 0.05, y: -s * 0.02)
            Image(systemName: "doc.text").font(.system(size: s * 0.22)).foregroundStyle(Brand.inkDim)
                .offset(x: -s * 0.55, y: s * 0.15)
        case .writing:
            Image(systemName: "pencil").font(.system(size: s * 0.24, weight: .bold)).foregroundStyle(tint)
                .rotationEffect(.degrees(-20 + 10 * sin(t * 8)))
                .offset(x: s * 0.52, y: s * 0.02)
            Image(systemName: "doc.text").font(.system(size: s * 0.22)).foregroundStyle(Brand.inkDim)
                .offset(x: -s * 0.55, y: s * 0.15)
        case .browsing:
            Image(systemName: "globe").font(.system(size: s * 0.26, weight: .medium)).foregroundStyle(tint)
                .rotationEffect(.degrees(t * 60))
                .offset(x: s * 0.55, y: -s * 0.05)
        case .plugging:
            Image(systemName: "powerplug.fill").font(.system(size: s * 0.24)).foregroundStyle(tint)
                .rotationEffect(.degrees(90))
                .offset(x: s * 0.55 + CGFloat(sin(t * 10)) * s * 0.03, y: s * 0.12)
            if sin(t * 13) > 0.5 {
                Image(systemName: "bolt.fill").font(.system(size: s * 0.16)).foregroundStyle(Color(light: 0xE0A21C, dark: 0xF2B544))
                    .offset(x: s * 0.72, y: -s * 0.02)
            }
        case .delegating:
            // Kichkina robot-yordamchi yonida
            RoundedRectangle(cornerRadius: s * 0.06, style: .continuous).fill(Brand.surface)
                .overlay(RoundedRectangle(cornerRadius: s * 0.06, style: .continuous).stroke(color.opacity(0.7), lineWidth: 1))
                .overlay(HStack(spacing: s * 0.04) { Circle().fill(Brand.ok).frame(width: s * 0.04); Circle().fill(Brand.ok).frame(width: s * 0.04) })
                .frame(width: s * 0.26, height: s * 0.2)
                .offset(x: s * 0.62, y: s * 0.3 - CGFloat(abs(sin(t * 5))) * s * 0.06)
        case .tinkering:
            Image(systemName: "wrench.adjustable.fill").font(.system(size: s * 0.22)).foregroundStyle(tint)
                .rotationEffect(.degrees(-30 + 35 * sin(t * 9)))
                .offset(x: s * 0.55, y: s * 0.02)
        case .thinking:
            Image(systemName: sin(t * 2) > 0.2 ? "lightbulb.max.fill" : "lightbulb")
                .font(.system(size: s * 0.22)).foregroundStyle(sin(t * 2) > 0.2 ? Color(light: 0xE0A21C, dark: 0xF2B544) : Brand.inkDim)
                .offset(x: s * 0.48, y: -s * 0.5)
        case .answering:
            Image(systemName: "text.bubble.fill").font(.system(size: s * 0.24)).foregroundStyle(tint.opacity(0.85))
                .offset(x: s * 0.55, y: -s * 0.3 + CGFloat(sin(t * 3)) * s * 0.03)
        case .waiting:
            Text("?").font(.system(size: s * 0.3, weight: .black, design: .rounded)).foregroundStyle(tint)
                .offset(x: -s * 0.52, y: -s * 0.4 + CGFloat(sin(t * 4)) * s * 0.04)
        case .error:
            Image(systemName: "drop.fill").font(.system(size: s * 0.12)).foregroundStyle(Color(light: 0x2F7BE5, dark: 0x4A8FF0))
                .offset(x: -s * 0.32, y: -s * 0.25 + CGFloat(t.truncatingRemainder(dividingBy: 1.2)) * s * 0.2)
        case .greeting:
            Text("!").font(.system(size: s * 0.32, weight: .black, design: .rounded)).foregroundStyle(tint)
                .offset(x: -s * 0.5, y: -s * 0.45)
                .scaleEffect(1 + 0.15 * abs(sin(t * 6)))
        case .watching:
            // Durbin ko'z oldida, bosh bilan birga buriladi
            Image(systemName: "binoculars.fill").font(.system(size: s * 0.28)).foregroundStyle(Brand.inkDim)
                .offset(x: CGFloat(sin(t * 0.9)) * s * 0.08, y: -s * 0.12)
        case .hello:
            Text("👋").font(.system(size: s * 0.24)).offset(x: s * 0.55, y: -s * 0.35)
                .rotationEffect(.degrees(20 * sin(t * 11)))
        case .celebrating, .sleeping:
            EmptyView()
        }
    }

    /// Atrofdagi effektlar: to'lqinlar, yulduzchalar
    @ViewBuilder
    private func effects(_ t: Double) -> some View {
        let s = size
        switch action {
        case .browsing:
            ForEach(0..<2, id: \.self) { i in
                let k = (t * 0.8 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
                Circle().stroke(tint.opacity(0.5 * (1 - k)), lineWidth: 1.4)
                    .frame(width: s * (0.3 + CGFloat(k) * 0.6), height: s * (0.3 + CGFloat(k) * 0.6))
                    .offset(x: s * 0.55, y: -s * 0.05)
            }
        case .celebrating:
            ForEach(0..<5, id: \.self) { i in
                let a = Double(i) / 5 * 2 * .pi + t * 1.5
                let r = s * (0.55 + 0.08 * CGFloat(sin(t * 4 + Double(i))))
                Image(systemName: "sparkle").font(.system(size: s * 0.14))
                    .foregroundStyle(i % 2 == 0 ? tint : Brand.inkFill)
                    .offset(x: CGFloat(cos(a)) * r, y: CGFloat(sin(a)) * r * 0.7 - s * 0.1)
                    .opacity(0.5 + 0.5 * sin(t * 6 + Double(i)))
            }
        case .sleeping:
            ForEach(0..<2, id: \.self) { i in
                let k = (t * 0.35 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
                Text("z").font(.system(size: s * (0.14 + 0.08 * CGFloat(k)), weight: .bold, design: .rounded))
                    .foregroundStyle(Brand.inkDim.opacity(1 - k))
                    .offset(x: s * (0.35 + 0.2 * CGFloat(k)), y: -s * (0.35 + 0.35 * CGFloat(k)))
            }
        default:
            EmptyView()
        }
    }
}

/// Yarim yoy: `up` — tepaga qaragan (^), aks holda pastga (tabassum)
private struct Arc: Shape {
    let up: Bool
    func path(in r: CGRect) -> Path {
        var p = Path()
        if up {
            p.move(to: CGPoint(x: r.minX, y: r.maxY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY), control: CGPoint(x: r.midX, y: r.minY - r.height * 0.6))
        } else {
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.midX, y: r.maxY + r.height * 0.6))
            p.closeSubpath()
        }
        return p
    }
}

/// Gap pufagi: yumaloq to'rtburchak va pastki o'rtada robotga qaragan dum
private struct SpeechBubble: Shape {
    let tail: CGFloat
    func path(in r: CGRect) -> Path {
        let body = CGRect(x: r.minX, y: r.minY, width: r.width, height: r.height)
        var p = Path(roundedRect: body, cornerRadius: min(body.height / 2, 12), style: .continuous)
        p.move(to: CGPoint(x: body.midX - tail, y: body.maxY - 0.5))
        p.addLine(to: CGPoint(x: body.midX, y: body.maxY + tail))
        p.addLine(to: CGPoint(x: body.midX + tail, y: body.maxY - 0.5))
        p.closeSubpath()
        return p
    }
}

extension RobotView {
    /// Robot nima qilishi — sessiyaning haqiqiy holatidan (Xulosa va Xarita'da bir xil).
    /// Bajarilayotgan qadam bo'lsa — uning turi; aks holda xato, yangi so'rov, javob, o'ylash, tugash yoki uyqu
    static func action(for session: SessionSnap, waiting: Bool, now: Date = Date()) -> Action {
        if waiting { return .waiting }
        let steps = session.agents.flatMap(\.steps)
        if let r = steps.filter({ $0.status == .running }).max(by: { $0.date < $1.date }) {
            let name = r.targetName.isEmpty ? r.category.title : r.targetName
            switch r.category {
            case .shell: return .typing(name)
            case .files: return r.access == .write ? .writing(name) : .reading(name)
            case .web: return .browsing(name)
            case .mcp: return .plugging(name)
            case .agent: return .delegating(name)
            case .other: return .tinkering(name)
            }
        }
        if session.state != .idle {
            if let last = steps.max(by: { $0.date < $1.date }), last.status == .failed, now.timeIntervalSince(last.date) < 15 {
                return .error
            }
            if let t = session.turns.last, t.active, now.timeIntervalSince(t.start) < 8, t.steps == 0 { return .greeting }
            if isAnsweredAction(session.main?.lastAction) { return .answering }
            return .thinking
        }
        if let la = session.lastActivity, now.timeIntervalSince(la) < 40 { return .celebrating }
        return .sleeping
    }
}
