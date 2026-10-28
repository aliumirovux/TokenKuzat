import SwiftUI
import TokenKuzatCore

/// Xarita pastidagi yozish maydoni: xabar shu sessiyaga ketadi, Claude javobi xaritada paydo bo'ladi
struct MapChatBar: View {
    let session: SessionSnap
    /// Xabar yuborilgach — xarita yangi kartaga ergashsin
    var onSent: () -> Void = {}
    @ObservedObject private var chat = MapChat.shared
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        let phase = chat.phase(session.id)
        let running: Bool = { if case .running = phase { return true }; return false }()
        let busyElsewhere = !running && session.state != .idle
        VStack(alignment: .leading, spacing: 6) {
            if case .failed(let msg) = phase {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(msg).lineLimit(2)
                    Spacer(minLength: 4)
                    Button { chat.dismissError(session.id) } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                }
                .font(.caption).foregroundStyle(Brand.warn)
            } else if chat.openElsewhere.contains(session.id) && !running {
                Label("Bu sessiya Claude ilovasida yoki terminalda ochiq — bu yerdan yozilganlar u yerda qayta ochgandagina ko'rinadi",
                      systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            HStack(alignment: .bottom, spacing: 8) {
                if running {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Claude ishlayapti — xaritada kuzating").font(.callout).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
                    Button { chat.stop(session.id) } label: {
                        Label("To'xtatish", systemImage: "stop.fill")
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 12).frame(height: 30)
                            .foregroundStyle(.white)
                            .background(Capsule().fill(Brand.warn))
                    }
                    .buttonStyle(.plain)
                    .help("Joriy ishni to'xtatish (Ctrl-C kabi) — sessiya saqlanadi")
                } else {
                    TextField(busyElsewhere ? "Claude boshqa joyda ishlayapti — tugashini kuting"
                                            : "Claude'ga yozing… (Enter — yuborish, ⌥Enter — yangi qator)",
                              text: $text, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.callout)
                        .lineLimit(1...6)
                        .focused($focused)
                        .disabled(busyElsewhere)
                        .onSubmit(send)
                        .modifier(ReturnSends(send: send))
                        .frame(minHeight: 30)
                    Button(action: send) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 30, height: 30)
                            .foregroundStyle(.white)
                            .background(Circle().fill(canSend(busyElsewhere) ? Brand.accent : Color.secondary.opacity(0.35)))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend(busyElsewhere))
                    .keyboardShortcut(.return, modifiers: .command)
                    .help("Yuborish — shu sessiyaga, avto ruxsat rejimida")
                }
            }
            .padding(.leading, 14).padding(.trailing, 6).padding(.vertical, 6)
            .surface(radius: 20, interactive: true)
            Text("Shu sessiyaga · \(session.model) · avto ruxsat rejimi")
                .font(.caption2).foregroundStyle(.tertiary)
                .padding(.leading, 14)
        }
        .task(id: session.id) {
            while !Task.isCancelled {
                await chat.refreshOpenElsewhere(session.id)
                try? await Task.sleep(nanoseconds: 6_000_000_000)
            }
        }
    }

    private func canSend(_ busy: Bool) -> Bool {
        !busy && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        guard canSend(session.state != .idle) else { return }
        chat.send(text, to: session)
        if case .running = chat.phase(session.id) {
            text = ""
            onSent()
        }
    }
}

/// Ko'p qatorli maydonda Return yangi qator qo'shishi mumkin — Enter yuboradi, ⌥/⇧Enter — yangi qator (macOS 14+)
private struct ReturnSends: ViewModifier {
    let send: () -> Void

    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.onKeyPress(.return, phases: .down) { press in
                if press.modifiers.contains(.option) || press.modifiers.contains(.shift) { return .ignored }
                send()
                return .handled
            }
        } else {
            content
        }
    }
}
