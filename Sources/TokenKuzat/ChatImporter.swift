import AppKit
import UniformTypeIdentifiers
import TokenKuzatCore

/// Bulutdagi chat yozuvini (.jsonl) qo'shish: fayl tanlash oynasi yoki oynaga sudrab tashlash.
/// Fayl ixchamlanib ilova papkasiga ko'chiriladi, Engine uni bir necha soniyada «Claude chat» sessiyasi sifatida o'qiydi.
enum ChatImporter {
    static func pick() {
        let p = NSOpenPanel()
        p.title = tr("Chat yozuvini qo'shish", "Add chat transcript")
        p.message = tr("Claude chatdan olingan .jsonl yozuv faylini tanlang", "Choose a .jsonl transcript exported from Claude chat")
        p.allowedContentTypes = [UTType(filenameExtension: "jsonl") ?? .json, .json, .plainText]
        p.allowsMultipleSelection = true
        p.canChooseDirectories = false
        guard p.runModal() == .OK else { return }
        add(p.urls)
    }

    /// Qo'shilganlar soni
    @discardableResult
    static func add(_ urls: [URL]) -> Int {
        var ok = 0
        var failed: [String] = []
        for u in urls where u.pathExtension.lowercased() == "jsonl" {
            do {
                try ChatImport.importFile(u)
                ok += 1
            } catch {
                failed.append(u.lastPathComponent + " — " + error.localizedDescription)
            }
        }
        if ok > 0 { WindowManager.shared.show(.sessions) }
        if !failed.isEmpty || ok == 0 {
            let a = NSAlert()
            a.messageText = ok == 0 ? tr("Chat yozuvi qo'shilmadi", "Chat transcript wasn't added") : tr("\(ok) ta qo'shildi, ba'zilari qo'shilmadi", "\(ok) added, some weren't")
            a.informativeText = failed.isEmpty ? tr("Faqat .jsonl fayllar qabul qilinadi.", "Only .jsonl files are accepted.") : failed.joined(separator: "\n")
            a.runModal()
        }
        return ok
    }
}
