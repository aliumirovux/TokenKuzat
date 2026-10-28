import SwiftUI

/// Jonli chiziq: ustidan ma'lumot paketlari yuradi — so'rov oldinga (asosiy rangda), javob orqaga (ochroq).
/// Har paket — «kometa»: yorqin bosh va so'nib boruvchi iz; harakat ease-in-out, paketlar orasida kechikish.
/// Canvas ichidan chaqiriladi (TimelineView vaqti bilan) — qo'shimcha view yaratmaydi, yengil.
enum DataFlow {
    /// - Parameters:
    ///   - t: TimelineView vaqti (soniya)
    ///   - seed: har chiziq uchun boshqacha faza — hammasi bir vaqtda «urilmasin»
    ///   - duplex: javob paketi ham orqaga yursinmi
    static func draw(_ g: inout GraphicsContext, path: Path, color: Color, t: Double, seed: Double,
                     width: CGFloat = 2, duplex: Bool = true) {
        // Asos: ingichka chiziq + juda yengil yorug'lik
        g.stroke(path, with: .color(color.opacity(0.10)), style: StrokeStyle(lineWidth: width + 6, lineCap: .round))
        g.stroke(path, with: .color(color.opacity(0.35)), style: StrokeStyle(lineWidth: width, lineCap: .round))

        let period = 1.9
        let base = (t / period + seed).truncatingRemainder(dividingBy: 1)
        // Oldinga: 2 ta paket, yarim davr oraliq bilan
        for k in 0..<2 {
            let f = ease((base + Double(k) * 0.5).truncatingRemainder(dividingBy: 1))
            comet(&g, path: path, at: f, reverse: false, color: color, width: width)
        }
        // Orqaga: javob — ochroq, kichikroq, boshqa fazada
        if duplex {
            let fb = ease((base + 0.27).truncatingRemainder(dividingBy: 1))
            comet(&g, path: path, at: fb, reverse: true, color: color.mix(with: .white, by: 0.45), width: width * 0.8)
        }
    }

    /// Tezlanib-sekinlashuvchi yumshoq harakat
    private static func ease(_ x: Double) -> Double {
        x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
    }

    private static func comet(_ g: inout GraphicsContext, path: Path, at f: Double, reverse: Bool,
                              color: Color, width: CGFloat) {
        let head = reverse ? 1 - f : f
        let tail = 0.16
        // Iz: bir necha bo'lak, boshga yaqinlashgan sari yorqinroq va qalinroq
        let segments = 6
        for i in 0..<segments {
            let a = Double(i) / Double(segments), b = Double(i + 1) / Double(segments)
            let from = reverse ? head + tail * (1 - a) : head - tail * (1 - a)
            let to = reverse ? head + tail * (1 - b) : head - tail * (1 - b)
            let lo = max(0, min(from, to)), hi = min(1, max(from, to))
            guard hi > lo else { continue }
            let seg = path.trimmedPath(from: lo, to: hi)
            g.stroke(seg, with: .color(color.opacity(0.08 + 0.55 * b)),
                     style: StrokeStyle(lineWidth: width + 1.5 * CGFloat(b), lineCap: .round))
        }
        // Bosh: yorug'lik halqasi + yorqin nuqta. Chiziq chetlarida so'nadi (paket «kirib-chiqadi»)
        guard head > 0.001, head < 0.999, let p = path.trimmedPath(from: 0, to: head).currentPoint else { return }
        let fade = min(1, min(head, 1 - head) * 8)
        let r = width + 2.2
        g.fill(Path(ellipseIn: CGRect(x: p.x - r * 2.4, y: p.y - r * 2.4, width: r * 4.8, height: r * 4.8)),
               with: .radialGradient(Gradient(colors: [color.opacity(0.45 * fade), color.opacity(0)]),
                                     center: p, startRadius: 0, endRadius: r * 2.4))
        g.fill(Path(ellipseIn: CGRect(x: p.x - r / 2, y: p.y - r / 2, width: r, height: r)),
               with: .color(Color.white.opacity(0.95 * fade)))
    }
}

extension Color {
    /// macOS 13–14 da Color.mix yo'q — oddiy aralashtirish
    func mix(with other: Color, by amount: Double) -> Color {
        let a = NSColor(self).usingColorSpace(.sRGB) ?? .gray
        let b = NSColor(other).usingColorSpace(.sRGB) ?? .white
        let k = CGFloat(amount)
        return Color(.sRGB, red: Double(a.redComponent + (b.redComponent - a.redComponent) * k),
                     green: Double(a.greenComponent + (b.greenComponent - a.greenComponent) * k),
                     blue: Double(a.blueComponent + (b.blueComponent - a.blueComponent) * k),
                     opacity: Double(a.alphaComponent))
    }
}
