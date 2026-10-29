import SwiftUI
import AppKit
import TokenKuzatCore

enum Section: String, CaseIterable, Identifiable {
    case overview, live, office, graph, sessions, history, savings, activity, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return tr("Bugun", "Today")
        case .live: return tr("Jonli", "Live")
        case .office: return tr("Ofis", "Office")
        case .graph: return tr("Sessiya", "Session")
        case .sessions: return tr("Sessiyalar", "Sessions")
        case .history: return tr("Tarix", "History")
        case .savings: return tr("Tejash", "Savings")
        case .activity: return tr("Jonli lenta", "Activity feed")
        case .settings: return tr("Sozlamalar", "Settings")
        }
    }

    var symbol: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .live: return "rectangle.grid.2x2"
        case .office: return "building.2"
        case .graph: return "point.3.connected.trianglepath.dotted"
        case .sessions: return "rectangle.stack"
        case .history: return "calendar"
        case .savings: return "leaf"
        case .activity: return "waveform.path.ecg"
        case .settings: return "gearshape"
        }
    }
}

/// Katta oyna. Ochiq turganda ilova Dock va Cmd-Tab'da ko'rinadi, yopilganda yana faqat menyu satrida qoladi.
final class WindowManager: NSObject, NSWindowDelegate {
    static let shared = WindowManager()
    private var window: NSWindow?
    /// Oyna ko'rinmay qolganda (orqada, Dock'da) shu yerda saqlanadi — holat yo'qolmaydi, chizish to'xtaydi
    private var parked: NSView?

    func show(_ section: Section? = nil) {
        if let section { UserDefaults.standard.set(section.rawValue, forKey: Pref.section) }
        if window == nil {
            let root = LanguageScope { MainWindow() }.environmentObject(Store.shared)
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 780),
                             styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.title = "Token Kuzatuv"
            w.titlebarAppearsTransparent = true
            // Sarlavha matni ko'rinmaydi (Dock va Mission Control uchun nomi saqlanadi)
            w.titleVisibility = .hidden
            w.toolbarStyle = .unified
            w.contentView = NSHostingView(rootView: root)
            parked = nil
            w.isReleasedWhenClosed = false
            w.setFrameAutosaveName("TokenKuzatMain")
            if !w.setFrameUsingName("TokenKuzatMain") { w.center() }
            w.delegate = self
            window = w
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        Store.shared.setVisible("window", true)
    }

    /// Oyna butunlay boshqa oynalar ortida yoki Dock'da: ko'rinish ajratib qo'yiladi (animatsiyalar to'xtaydi),
    /// yana ko'rinsa — qaytariladi
    func windowDidChangeOcclusionState(_ notification: Notification) {
        guard let w = window else { return }
        let visible = w.occlusionState.contains(.visible)
        Store.shared.setVisible("window", visible && w.isVisible)
        if !visible, parked == nil, let v = w.contentView {
            parked = v
            w.contentView = NSView(frame: v.frame)
        } else if visible, let v = parked {
            parked = nil
            w.contentView = v
        }
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Store.shared.setVisible("window", false)
        // Yopilgan oyna ko'rinishlari yo'q qilinadi: aks holda xarita, robot va oqim animatsiyalari ko'rinmasa ham
        // chizilishda davom etib, protsessorni band qiladi. Keyingi ochilishda oyna qaytadan yaratiladi.
        DispatchQueue.main.async { [weak self] in
            guard let self, let w = self.window, !w.isVisible else { return }
            w.delegate = nil
            w.contentView = nil
            self.parked = nil
            self.window = nil
        }
    }
}
