import SwiftUI
import TokenKuzatCore

/// Replay o'ynatgichi: ▶/⏸, vaqt slayderi (ustida — qadamlar belgilari), tezlik va «Jonli»ga qaytish.
struct ReplayBar: View {
    let range: ClosedRange<Date>
    let steps: [StepSnap]
    @Binding var time: Date?
    @Binding var playing: Bool
    @Binding var speed: Double

    private var duration: TimeInterval { max(1, range.upperBound.timeIntervalSince(range.lowerBound)) }

    var body: some View {
        let t = time ?? range.upperBound
        HStack(spacing: 12) {
            Button {
                if t >= range.upperBound { time = range.lowerBound }
                playing.toggle()
            } label: {
                Image(systemName: playing ? "pause.fill" : "play.fill").frame(width: 20)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.space, modifiers: [])
            .help(playing ? "Pauza (bo'sh joy)" : "Ijro etish (bo'sh joy)")

            Button { step(-1) } label: { Image(systemName: "backward.end.fill") }
                .buttonStyle(.borderless).help("Oldingi qadam")
            Button { step(1) } label: { Image(systemName: "forward.end.fill") }
                .buttonStyle(.borderless).help("Keyingi qadam")

            VStack(spacing: 2) {
                StepTicks(steps: steps, range: range, duration: duration).frame(height: 8).padding(.horizontal, 8)
                Slider(value: Binding(
                    get: { t.timeIntervalSince(range.lowerBound) },
                    set: { time = range.lowerBound.addingTimeInterval($0); playing = false }),
                       in: 0...duration)
                    .controlSize(.small)
            }

            VStack(alignment: .trailing, spacing: 0) {
                Text(Fmt.clock.string(from: t)).font(.caption.monospacedDigit().weight(.semibold))
                Text("+\(Alerts.duration(t.timeIntervalSince(range.lowerBound))) / \(Alerts.duration(duration))")
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            .frame(width: 120, alignment: .trailing)

            Picker("Tezlik", selection: $speed) {
                Text("1×").tag(1.0)
                Text("5×").tag(5.0)
                Text("20×").tag(20.0)
                Text("60×").tag(60.0)
            }
            .labelsHidden()
            .frame(width: 64)
            .help("Ijro tezligi")

            Button {
                playing = false
                time = nil
            } label: {
                Label("Jonli", systemImage: "dot.radiowaves.left.and.right")
            }
            .help("Replay'dan chiqib, hozirgi holatga qaytish")
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .glass(radius: 14, tint: .accentColor)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    /// Qadamdan qadamga sakrash
    private func step(_ dir: Int) {
        playing = false
        let t = time ?? range.upperBound
        let dates = steps.map(\.date).sorted()
        if dir > 0 {
            time = dates.first { $0 > t.addingTimeInterval(0.01) } ?? range.upperBound
        } else {
            time = dates.last { $0 < t.addingTimeInterval(-0.01) } ?? range.lowerBound
        }
    }
}

/// Slayder ustidagi belgilar — har bir qadam o'z rangida, xatolar qizil
private struct StepTicks: View {
    let steps: [StepSnap]
    let range: ClosedRange<Date>
    let duration: TimeInterval

    var body: some View {
        Canvas { g, size in
            for s in steps {
                let x = CGFloat(s.date.timeIntervalSince(range.lowerBound) / duration) * size.width
                let color: Color = s.status == .failed ? .red : s.category.color
                g.fill(Path(CGRect(x: x - 0.75, y: 0, width: 1.5, height: size.height)), with: .color(color.opacity(0.8)))
            }
        }
    }
}
