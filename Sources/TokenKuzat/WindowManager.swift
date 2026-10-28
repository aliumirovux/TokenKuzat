import SwiftUI
import AppKit

enum Section: String, CaseIterable, Identifiable {
    case overview, graph, sessions, history, activity, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Bugun"
        case .graph: return "Sessiya"
        case .sessions: return "Sessiyalar"
        case .history: return "Tarix"
        case .activity: return "Jonli lenta"
        case .settings: return "Sozlamalar"
        }
    }

    var symbol: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .graph: return "point.3.connected.trianglepath.dotted"
        case .sessions: return "rectangle.stack"
        case .history: return "calendar"
        case .activity: return "waveform.path.ecg"
        case .settings: return "gearshape"
        }
    }
}

/// Katta oyna. Ochiq turganda ilova Dock va Cmd-Tab'da ko'rinadi, yopilganda yana faqat menyu satrida qoladi.
final class WindowManager: NSObject, NSWindowDelegate {
    static let shared = WindowManager()
    private var window: NSWindow?

    func show(_ section: Section? = nil) {
        if let section { UserDefaults.standard.set(section.rawValue, forKey: Pref.section) }
        if window == nil {
            let root = MainWindow().environmentObject(Store.shared)
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 780),
                             styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.title = "Token Kuzatuv"
            w.titlebarAppearsTransparent = true
            w.toolbarStyle = .unified
            w.contentView = NSHostingView(rootView: root)
            w.isReleasedWhenClosed = false
            w.setFrameAutosaveName("TokenKuzatMain")
            if !w.setFrameUsingName("TokenKuzatMain") { w.center() }
            w.delegate = self
            window = w
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
