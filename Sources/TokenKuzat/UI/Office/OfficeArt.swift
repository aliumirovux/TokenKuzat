import AppKit

// Ofis sahnasi uchun 2D rasmlar: pol, gilam, robot yuzi, belgilar, pufakchalar, yorliqlar va monitor ekrani.
// Hammasi Core Graphics bilan chiziladi; koordinatalar tepadan pastga (kanvas kabi).

enum OfficeArt {
    static let accent = 0x8F82FF, helper = 0x4FC3D9, ok = 0x3DD68C, warn = 0xF2B544, err = 0xFF6E61

    /// Takrorlanadigan tasodif — har ochilishda bir xil naqsh
    struct Rand {
        var seed: Int
        mutating func next() -> CGFloat {
            seed = (seed * 16807) % 2147483647
            return CGFloat(seed) / 2147483647
        }
    }

    static func image(_ w: Int, _ h: Int, _ draw: (CGContext) -> Void) -> CGImage {
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
        draw(ctx)
        NSGraphicsContext.restoreGraphicsState()
        return ctx.makeImage()!
    }

    static func color(_ hex: Int, _ alpha: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }

    static func hsl(_ h: CGFloat, _ s: CGFloat, _ l: CGFloat, _ a: CGFloat = 1) -> CGColor {
        let c = (1 - abs(2 * l - 1)) * s, hp = (h.truncatingRemainder(dividingBy: 360)) / 60
        let x = c * (1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1)), m = l - c / 2
        let (r, g, b): (CGFloat, CGFloat, CGFloat) = switch Int(hp) {
        case 0: (c, x, 0)
        case 1: (x, c, 0)
        case 2: (0, c, x)
        case 3: (0, x, c)
        case 4: (x, 0, c)
        default: (c, 0, x)
        }
        return CGColor(srgbRed: r + m, green: g + m, blue: b + m, alpha: a)
    }

    // MARK: Materiallar

    static func woodFloor() -> CGImage {
        var r = Rand(seed: 7)
        return image(512, 512) { c in
            let rows = 8, rh: CGFloat = 512 / CGFloat(rows)
            for row in 0..<rows {
                var x = -r.next() * 220
                let y0 = CGFloat(row) * rh
                while x < 512 {
                    let len = 170 + r.next() * 210
                    c.setFillColor(hsl(27 + r.next() * 6, 0.30 + r.next() * 0.10, 0.50 + r.next() * 0.09))
                    c.fill(CGRect(x: x, y: y0, width: len, height: rh))
                    for _ in 0..<7 {
                        let y = y0 + r.next() * rh
                        c.setStrokeColor(color(0x50301A, 0.06 + r.next() * 0.09)); c.setLineWidth(1)
                        c.move(to: CGPoint(x: x, y: y))
                        c.addCurve(to: CGPoint(x: x + len, y: y + (r.next() - 0.5) * 4),
                                   control1: CGPoint(x: x + len * 0.3, y: y + (r.next() - 0.5) * 6),
                                   control2: CGPoint(x: x + len * 0.6, y: y + (r.next() - 0.5) * 6))
                        c.strokePath()
                    }
                    c.setFillColor(color(0x28180C, 0.35)); c.fill(CGRect(x: x, y: y0, width: 1.5, height: rh))
                    x += len
                }
                c.setFillColor(color(0x28180C, 0.3)); c.fill(CGRect(x: 0, y: y0, width: 512, height: 1.5))
            }
        }
    }

    static func concrete() -> CGImage {
        var r = Rand(seed: 3)
        return image(256, 256) { c in
            c.setFillColor(color(0xC9C5BD)); c.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
            for _ in 0..<2600 {
                c.setFillColor(color(r.next() > 0.5 ? 0xFFFFFF : 0x3C3732, r.next() * 0.06))
                c.fill(CGRect(x: r.next() * 256, y: r.next() * 256, width: 2, height: 2))
            }
        }
    }

    static func grass() -> CGImage {
        var r = Rand(seed: 5)
        return image(256, 256) { c in
            c.setFillColor(color(0x4C6B3C)); c.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
            for _ in 0..<5000 {
                c.setFillColor(hsl(85 + r.next() * 30, 0.35 + r.next() * 0.2, 0.25 + r.next() * 0.22, 0.55))
                c.fill(CGRect(x: r.next() * 256, y: r.next() * 256, width: 1.5, height: 3))
            }
        }
    }

    static let rugColors = [0xD9CBB4, 0xC9D3CF, 0xD6C4C0, 0xCFD0DC, 0xD8D0BD, 0xD3CDBF]

    static func rug(_ i: Int) -> CGImage {
        var r = Rand(seed: 13 + i)
        return image(256, 256) { c in
            c.setFillColor(color(rugColors[i % rugColors.count])); c.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
            c.setStrokeColor(color(0x3C3228, 0.25))
            c.setLineWidth(6); c.stroke(CGRect(x: 18, y: 18, width: 220, height: 220))
            c.setLineWidth(2); c.stroke(CGRect(x: 32, y: 32, width: 192, height: 192))
            for _ in 0..<1800 {
                c.setFillColor(color(0, r.next() * 0.05)); c.fill(CGRect(x: r.next() * 256, y: r.next() * 256, width: 2, height: 2))
            }
        }
    }

    /// Osmon va yer — yorug'lik muhiti (gradient)
    static func environment(sky: Int, ground: Int) -> CGImage {
        image(64, 32) { c in
            let g = CGGradient(colorsSpace: nil, colors: [color(sky), color(sky), color(ground)] as CFArray, locations: [0, 0.45, 0.6])!
            c.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: 32), options: [])
        }
    }

    // MARK: Robot yuzi

    enum Emotion: String { case focus, think, wide, sad, happy, sleep }

    /// Ko'zlar holatga qarab: diqqatli, yuqoriga qaragan, katta, xafa, xursand yoki yumuq
    static func face(_ emo: Emotion, lx: CGFloat, ly: CGFloat, blink: Bool, tint: Int, eyes: [CGFloat], k: CGFloat) -> CGImage {
        image(128, 76) { c in
            let col = color(tint)
            c.setFillColor(col); c.setStrokeColor(col); c.setLineCap(.round)
            c.setShadow(offset: .zero, blur: 9, color: col)
            let cy = 38 + ly * 9
            for ox in eyes {
                let side: CGFloat = ox < 0 ? -1 : 1, x = 64 + ox + lx * 11
                c.setLineWidth(7 * k)
                if emo == .sleep || (blink && emo != .happy) {
                    c.move(to: CGPoint(x: x - 10 * k, y: cy + 3)); c.addLine(to: CGPoint(x: x + 10 * k, y: cy + 3)); c.strokePath()
                    continue
                }
                if emo == .happy {
                    c.addArc(center: CGPoint(x: x, y: cy + 9 * k), radius: 12 * k, startAngle: .pi * 1.18, endAngle: .pi * 1.82, clockwise: false)
                    c.strokePath()
                    continue
                }
                let ew = (emo == .wide ? 24 : 21) * k, eh = (emo == .wide ? 34 : emo == .focus ? 17 : 29) * k
                let top = cy - eh / 2, inner = x - side * ew / 2, outer = x + side * ew / 2
                c.addPath(CGPath(roundedRect: CGRect(x: x - ew / 2, y: top, width: ew, height: eh),
                                 cornerWidth: min(9 * k, ew / 2), cornerHeight: min(9 * k, eh / 2), transform: nil))
                c.fillPath()
                c.saveGState()
                c.setBlendMode(.clear); c.setShadow(offset: .zero, blur: 0, color: nil)
                if emo == .sad { // ko'z chetlari pastga — xafa
                    c.move(to: CGPoint(x: inner - side * 4, y: top - 12)); c.addLine(to: CGPoint(x: outer + side * 4, y: top - 12))
                    c.addLine(to: CGPoint(x: outer + side * 4, y: top + eh * 0.5)); c.addLine(to: CGPoint(x: inner - side * 4, y: top + 2))
                    c.fillPath()
                }
                if emo == .think { c.fill(CGRect(x: x - ew, y: cy + eh * 0.16, width: ew * 2, height: eh)) } // yuqoriga qarab ko'zini qisadi
                c.restoreGState()
                if emo == .wide { // qosh ko'tarilgan
                    c.setLineWidth(4 * k)
                    c.addArc(center: CGPoint(x: x, y: top + 2), radius: ew * 0.62, startAngle: .pi * 1.25, endAngle: .pi * 1.75, clockwise: false)
                    c.strokePath()
                }
            }
        }
    }

    // MARK: Belgilar

    enum Badge { case waiting, error, thinking, z }

    static func badge(_ kind: Badge) -> CGImage {
        image(128, 128) { c in
            c.setLineCap(.round)
            switch kind {
            case .waiting, .error:
                let hex = kind == .waiting ? warn : err
                c.setShadow(offset: .zero, blur: 18, color: color(hex, 0.8))
                c.setFillColor(color(hex)); c.fillEllipse(in: CGRect(x: 24, y: 24, width: 80, height: 80))
                c.setShadow(offset: .zero, blur: 0, color: nil)
                c.setStrokeColor(color(kind == .waiting ? 0x1A1406 : 0x2A0905)); c.setLineWidth(10)
                if kind == .waiting {
                    c.move(to: CGPoint(x: 64, y: 42)); c.addLine(to: CGPoint(x: 64, y: 68))
                    c.move(to: CGPoint(x: 64, y: 86)); c.addLine(to: CGPoint(x: 64, y: 86.5))
                } else {
                    c.move(to: CGPoint(x: 50, y: 50)); c.addLine(to: CGPoint(x: 78, y: 78))
                    c.move(to: CGPoint(x: 78, y: 50)); c.addLine(to: CGPoint(x: 50, y: 78))
                }
                c.strokePath()
            case .thinking:
                let pill = CGPath(roundedRect: CGRect(x: 10, y: 38, width: 108, height: 52), cornerWidth: 26, cornerHeight: 26, transform: nil)
                c.addPath(pill); c.setFillColor(color(0x1E1E28, 0.9)); c.fillPath()
                c.addPath(pill); c.setStrokeColor(color(0xFFFFFF, 0.25)); c.setLineWidth(3); c.strokePath()
                c.setFillColor(color(0xFFFFFF))
                for x in [40, 64, 88] as [CGFloat] { c.fillEllipse(in: CGRect(x: x - 7, y: 57, width: 14, height: 14)) }
            case .z:
                text("z", in: CGRect(x: 0, y: 14, width: 128, height: 100), size: 72, weight: .bold, color: NSColor.white.withAlphaComponent(0.9))
            }
        }
    }

    /// Yumshoq nur (karta atrofida)
    static func glow(_ hex: Int) -> CGImage {
        image(64, 64) { c in
            let g = CGGradient(colorsSpace: nil, colors: [color(hex), color(hex, 0)] as CFArray, locations: [0, 1])!
            c.drawRadialGradient(g, startCenter: CGPoint(x: 32, y: 32), startRadius: 0, endCenter: CGPoint(x: 32, y: 32), endRadius: 32, options: [])
        }
    }

    /// Nur konusi: tepasi yorug', pasti xira
    static func beam() -> CGImage {
        image(4, 128) { c in
            let g = CGGradient(colorsSpace: nil, colors: [color(0xFFFFFF), color(0x222222)] as CFArray, locations: [0, 1])!
            c.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: 128), options: [])
        }
    }

    // MARK: Matn

    static func text(_ s: String, in r: CGRect, size: CGFloat, weight: NSFont.Weight, color: NSColor, align: NSTextAlignment = .center) {
        let p = NSMutableParagraphStyle(); p.alignment = align; p.lineBreakMode = .byTruncatingTail
        let font = NSFont.systemFont(ofSize: size, weight: weight)
        let attr = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: p])
        let h = attr.size().height
        attr.draw(in: CGRect(x: r.minX, y: r.midY - h / 2, width: r.width, height: h))
    }

    static func width(_ s: String, size: CGFloat, weight: NSFont.Weight) -> CGFloat {
        NSAttributedString(string: s, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight)]).size().width
    }

    /// Robot ustidagi gap pufagi: «→ Explore», «✓ Tayyor»
    static func bubble(_ s: String, tint: Int) -> CGImage {
        image(256, 72) { c in
            let w = min(248, width(s, size: 30, weight: .semibold) + 40)
            let path = CGPath(roundedRect: CGRect(x: (256 - w) / 2, y: 8, width: w, height: 54), cornerWidth: 27, cornerHeight: 27, transform: nil)
            c.addPath(path); c.setFillColor(color(0x16161C, 0.92)); c.fillPath()
            c.addPath(path); c.setStrokeColor(color(tint)); c.setLineWidth(3); c.strokePath()
            text(s, in: CGRect(x: (256 - w) / 2 + 12, y: 8, width: w - 24, height: 54), size: 30, weight: .semibold, color: .white)
        }
    }

    /// Xona yorlig'i: harf, nom va holat. Ruxsat kutilsa — sariq chegara
    static func label(title: String, status: String, tint: Int, alert: Bool) -> CGImage {
        let size: CGFloat = 26, h: CGFloat = 60
        let tw = min(300, width(title, size: size, weight: .semibold))
        let sw = min(260, width("· " + status, size: size, weight: .medium))
        let w = 12 + 40 + 12 + tw + 10 + sw + 22
        return image(Int(ceil(w)) + 8, Int(h) + 8) { c in
            let r = CGRect(x: 4, y: 4, width: w, height: h)
            let path = CGPath(roundedRect: r, cornerWidth: h / 2, cornerHeight: h / 2, transform: nil)
            c.setShadow(offset: CGSize(width: 0, height: 2), blur: 6, color: color(0, 0.35))
            c.addPath(path); c.setFillColor(color(0x18181E, 0.86)); c.fillPath()
            c.setShadow(offset: .zero, blur: 0, color: nil)
            c.addPath(path); c.setStrokeColor(alert ? color(warn) : color(0xFFFFFF, 0.14)); c.setLineWidth(alert ? 3 : 1.5); c.strokePath()
            let av = CGRect(x: r.minX + 12, y: r.midY - 20, width: 40, height: 40)
            c.addPath(CGPath(roundedRect: av, cornerWidth: 11, cornerHeight: 11, transform: nil))
            c.setFillColor(color(accent)); c.fillPath()
            text(String(title.prefix(1)).uppercased(), in: av, size: 22, weight: .bold, color: .white)
            text(title, in: CGRect(x: av.maxX + 12, y: r.minY, width: tw + 2, height: h), size: size, weight: .semibold, color: .white, align: .left)
            text("· " + status, in: CGRect(x: av.maxX + 12 + tw + 10, y: r.minY, width: sw + 2, height: h), size: size, weight: .medium,
                 color: NSColor(cgColor: color(tint))!, align: .left)
        }
    }

    // MARK: Monitor

    /// Ekran: kod qatorlari va o'rtada hozirgi asbob belgisi. Bo'sh stolda — o'chiq
    static func screen(_ state: OfficeState?, tool: OfficeTool?) -> CGImage {
        image(256, 150) { c in
            guard let state, let look = screenLook(state) else {
                c.setFillColor(color(0x060709)); c.fill(CGRect(x: 0, y: 0, width: 256, height: 150)); return
            }
            c.setFillColor(color(look.bg)); c.fill(CGRect(x: 0, y: 0, width: 256, height: 150))
            c.setAlpha(0.4)
            for i in 0..<9 {
                c.setFillColor(color(i % 3 == 0 ? accent : 0x5D7DA6))
                c.fill(CGRect(x: 14 + CGFloat(i % 2) * 14, y: 14 + CGFloat(i) * 15, width: 30 + CGFloat((i * 53) % 90), height: 6))
            }
            c.setAlpha(1)
            c.translateBy(x: 256 * 0.7 - 36, y: 75 - 36); c.scaleBy(x: 6, y: 6)
            c.setStrokeColor(color(look.icon)); c.setLineWidth(state == .thinking ? 2.4 : 1.3)
            c.setLineCap(.round); c.setLineJoin(.round)
            c.setShadow(offset: .zero, blur: 14, color: color(look.icon))
            c.addPath(icon(state == .working ? (tool ?? .wrench) : nil, state: state))
            c.strokePath()
        }
    }

    struct ScreenLook { let bg: Int, icon: Int, light: Int }

    static func screenLook(_ s: OfficeState) -> ScreenLook? {
        switch s {
        case .working: return ScreenLook(bg: 0x0C1A2C, icon: 0xD8F1FF, light: 0x9FD8FF)
        case .thinking: return ScreenLook(bg: 0x14152A, icon: 0xB9BCE0, light: 0x9B9FC4)
        case .error: return ScreenLook(bg: 0x2A0D0D, icon: 0xFF8A7F, light: 0xFF6E61)
        default: return nil
        }
    }

    /// 12×12 katakdagi oddiy chiziqli belgilar
    private static func icon(_ tool: OfficeTool?, state: OfficeState) -> CGPath {
        let p = CGMutablePath()
        func line(_ pts: [(CGFloat, CGFloat)]) {
            p.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
            pts.dropFirst().forEach { p.addLine(to: CGPoint(x: $0.0, y: $0.1)) }
        }
        if state == .error { line([(6, 1.5), (10.8, 10), (1.2, 10), (6, 1.5)]); line([(6, 5), (6, 7)]); line([(6, 8.9), (6, 9)]); return p }
        if state == .thinking { [2.5, 6, 9.5].forEach { line([($0, 6), ($0 + 0.1, 6)]) }; return p }
        switch tool ?? .wrench {
        case .terminal: line([(2, 3.5), (5, 6), (2, 8.5)]); line([(6.5, 9), (10, 9)])
        case .file: line([(3, 1.5), (7, 1.5), (9.5, 4), (9.5, 10.5), (3, 10.5), (3, 1.5)]); line([(7, 1.5), (7, 4), (9.5, 4)])
        case .web:
            p.addEllipse(in: CGRect(x: 1.5, y: 1.5, width: 9, height: 9))
            p.addEllipse(in: CGRect(x: 4, y: 1.5, width: 4, height: 9))
            line([(1.5, 6), (10.5, 6)])
        case .plug: line([(4.5, 1.5), (4.5, 4)]); line([(7.5, 1.5), (7.5, 4)]); line([(2.5, 4), (9.5, 4), (9.5, 6), (6, 9), (2.5, 6), (2.5, 4)]); line([(6, 9), (6, 10.5)])
        case .agent:
            p.addEllipse(in: CGRect(x: 2, y: 2, width: 3.5, height: 3.5)); p.addEllipse(in: CGRect(x: 6.5, y: 2, width: 3.5, height: 3.5))
            line([(1.5, 10), (1.5, 8.5), (6, 7), (10.5, 8.5), (10.5, 10)])
        case .wrench: line([(2, 10), (6.5, 5.5)]); p.addEllipse(in: CGRect(x: 6, y: 2, width: 4, height: 4))
        }
        return p
    }
}
