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
            .help(playing ? tr("Pauza (bo'sh joy)", "Pause (Space)") : tr("Ijro etish (bo'sh joy)", "Play (Space)"))

            Button { step(-1) } label: { Image(systemName: "backward.end.fill") }
                .buttonStyle(.borderless).help(tr("Oldingi qadam", "Previous step"))
            Button { step(1) } label: { Image(systemName: "forward.end.fill") }
                .buttonStyle(.borderless).help(tr("Keyingi qadam", "Next step"))

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

            Picker(tr("Tezlik", "Speed"), selection: $speed) {
                Text("1×").tag(1.0)
                Text("5×").tag(5.0)
                Text("20×").tag(20.0)
                Text("60×").tag(60.0)
            }
            .labelsHidden()
            .frame(width: 64)
            .help(tr("Ijro tezligi", "Playback speed"))

            Button {
                playing = false
                time = nil
            } label: {
                Label(tr("Jonli", "Live"), systemImage: "dot.radiowaves.left.and.right")
            }
            .help(tr("Replay'dan chiqib, hozirgi holatga qaytish", "Exit replay and return to the current state"))
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .surface(radius: 14, tint: .accentColor)
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
