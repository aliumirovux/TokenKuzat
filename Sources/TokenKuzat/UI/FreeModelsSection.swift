import SwiftUI
import AppKit
import TokenKuzatCore

/// Sozlamalar → «Bepul modellar»: FreeLLMAPI manzili va kaliti, tekshiruv, limit tugaganda taklif va qo'lda ochish
struct FreeModelsSection: View {
    @EnvironmentObject var store: Store
    @AppStorage(Pref.freeFallback) private var freeFallback = false
    @State private var url = FreeModels.load()?.url ?? FreeModels.defaultURL
    @State private var key = FreeModels.load()?.key ?? ""
    @State private var saved = FreeModels.load() != nil
    @State private var check: FreeFallback.Check?
    @State private var checking = false
    @State private var error: String?

    var body: some View {
        SwiftUI.Section {
            TextField(tr("Manzil", "Address"), text: $url, prompt: Text(FreeModels.defaultURL))
            SecureField(tr("Umumiy kalit (freellmapi-…)", "Unified key (freellmapi-…)"), text: $key)
            HStack {
                statusView
                Spacer()
                if saved {
                    Button(tr("O'chirish", "Remove")) { remove() }.buttonStyle(.link)
                }
                Button(saved ? tr("Saqlash va tekshirish", "Save and check") : tr("Saqlash", "Save")) { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty || checking)
            }
            if let error {
                Label(error, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(Brand.err)
            }
            Toggle(tr("Claude limiti tugaganda — «Bepul modelda davom etish» tugmasi", "When the Claude limit runs out — «Continue on a free model» button"),
                   isOn: $freeFallback)
                .disabled(!saved || !AppInfo.isBundled)
            HStack {
                Button(tr("Hozir terminalda bepul modelda ochish", "Open on a free model in Terminal now")) { openNow() }
                    .disabled(!saved)
                Spacer()
                Button(tr("FreeLLMAPI haqida", "About FreeLLMAPI")) {
                    NSWorkspace.shared.open(URL(string: "https://github.com/tashfeenahmed/freellmapi")!)
                }
                .buttonStyle(.link)
            }
        } header: {
            Text(tr("Bepul modellar (FreeLLMAPI)", "Free models (FreeLLMAPI)"))
        } footer: {
            Text(tr("FreeLLMAPI — bepul tariflarni (Gemini, DeepSeek, Qwen, Llama…) bitta manzilga yig'adigan dastur; uni o'zingiz o'rnatasiz "
                    + "(Mac ilovasi — manzil http://127.0.0.1:31415, server versiyasi — http://localhost:3001; Mac ilovasi yopiq bo'lsa, Token Kuzatuv uni o'zi orqa fonda ochadi), "
                    + "provayder kalitlarini uning Keys sahifasida qo'shasiz va «Unified API key» ni shu yerga yozasiz. "
                    + "Limit tugaganda bildirishnomadagi tugma ishni xulosa bilan Terminal'dagi claude'da bepul modelga o'tkazadi; limit tiklanganda «Claude'da davom etish» uni qaytaradi. "
                    + "Claude Code uchun katta kontekstli va asboblarni chaqira oladigan model kerak (masalan, Google AI Studio — Gemini): faqat Groq kaliti bilan ishlamaydi. "
                    + "Claude ilovasidagi sessiyalar Claude'da qoladi. Claude'ga «ask_free_model» asbobi ham qo'shiladi (/mcp da tokenkuzat'ni qayta ulang): "
                    + "tarjima, uzun logni qisqartirish kabi mayda ishlarni bepul modelga beradi. Bepul modellar Claude'dan zaif va so'rovlarni o'qitishga ishlatishi mumkin — "
                    + "maxfiy kod va ma'lumotda ehtiyot bo'ling. Kalit faqat shu Mac'da (0600 fayl) saqlanadi va faqat shu manzilga yuboriladi; "
                    + "bepul model sarfi Claude limitiga qo'shilmaydi.",
                    "FreeLLMAPI is an app that pools free tiers (Gemini, DeepSeek, Qwen, Llama…) behind one address; you install it yourself "
                    + "(Mac app — address http://127.0.0.1:31415, server version — http://localhost:3001; if the Mac app is closed, Token Kuzatuv opens it in the background), "
                    + "add provider keys on its Keys page and paste its «Unified API key» here. "
                    + "When the limit runs out, the notification button moves the work with a summary to claude in Terminal on a free model; when the limit resets, «Continue in Claude» moves it back. "
                    + "Claude Code needs a model with a large context that can call tools (e.g. Google AI Studio — Gemini): a Groq key alone won't do. "
                    + "Sessions in the Claude app stay on Claude. Claude also gets an «ask_free_model» tool (reconnect tokenkuzat in /mcp) "
                    + "for small jobs like translating or summarizing a long log. Free models are weaker than Claude and may train on prompts — "
                    + "be careful with private code and data. The key is stored only on this Mac (0600 file) and sent only to this address; "
                    + "free-model usage doesn't count toward the Claude limit."))
                .font(.caption).foregroundStyle(.secondary)
        }
        .onAppear { if saved && check == nil { runCheck() } }
    }

    @ViewBuilder private var statusView: some View {
        if checking {
            ProgressView().controlSize(.small)
        } else if let check {
            HStack(spacing: 6) {
                Circle().fill(color(check)).frame(width: 8, height: 8)
                Text(text(check)).font(.caption)
            }
        } else if !saved {
            Text(tr("Sozlanmagan", "Not set up")).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func color(_ c: FreeFallback.Check) -> Color {
        if case .ok = c { return Brand.ok }
        return c == .notConfigured ? .secondary : Brand.err
    }

    private func text(_ c: FreeFallback.Check) -> String {
        switch c {
        case .ok(let n): return tr("Ishlayapti · \(n) ta model", "Working · \(n) models")
        case .badKey: return tr("Kalit noto'g'ri", "Wrong key")
        case .unreachable(let why): return tr("Ulanib bo'lmadi: \(why)", "Can't connect: \(why)")
        case .notConfigured: return tr("Sozlanmagan", "Not set up")
        }
    }

    private func save() {
        do {
            try FreeModels.save(.init(url: url, key: key))
            url = FreeModels.rootURL(url)
            saved = true
            error = nil
            runCheck()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func remove() {
        FreeModels.remove()
        key = ""
        saved = false
        freeFallback = false
        check = nil
    }

    private func runCheck() {
        checking = true
        FreeFallback.check(FreeModels.load()) { r in
            check = r
            checking = false
        }
    }

    private func openNow() {
        let sess = FreeFallback.source(in: store.snap)
        let resets = [store.snap.limits?.fiveHour, store.snap.limits?.sevenDay].compactMap { $0 }
            .filter { $0.usedPercentage >= 99.5 }.map(\.resetsAt).max()
        // Limit tugagan bo'lsa — ish xulosa bilan ko'chadi; aks holda shu loyihada bo'sh sessiya
        guard let resets else {
            if !FreeFallback.openBlank(near: sess) { error = tr("Terminalni ochib bo'lmadi", "Couldn't open Terminal") }
            return
        }
        FreeFallback.start(from: sess, resetsAt: resets) { ok in
            if !ok { error = tr("Terminalni ochib bo'lmadi", "Couldn't open Terminal") }
        }
    }
}
