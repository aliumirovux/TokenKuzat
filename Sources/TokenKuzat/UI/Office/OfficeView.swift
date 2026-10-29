import SwiftUI
import SceneKit
import TokenKuzatCore

/// «Ofis» — loyihalar xona, agentlar robot bo'lib ishlaydigan 3D bino.
/// Robotni bosish — sessiya xaritasi; xona yorlig'i yoki pastdagi ro'yxat — kamera o'sha xonaga;
/// dron (kuzatuvchi) — e'tibor kerak xonalarni aytadi
struct OfficeView: View {
    @EnvironmentObject var store: Store
    @AppStorage(Pref.section) private var section = Section.overview
    @AppStorage(GraphScreen.selectedSessionKey) private var sessionId = ""
    @AppStorage(Pref.lightMode) private var lightMode = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var world = OfficeWorld()
    @State private var toast: String?
    @State private var toastId = 0

    var body: some View {
        let rooms = OfficeModel.rooms(store.snap)
        // Tugmalar 3D maydon ustida emas, ostida: AppKit ko'rinishi ustidagi SwiftUI tugmalariga bosish yetib bormaydi
        VStack(spacing: 12) {
            OfficeSceneView(world: world, rooms: rooms, still: reduceMotion || lightMode, onPick: pick)
                .overlay(alignment: .topLeading) {
                    Text(tr("Sudrab aylantiring · chimdib yaqinlashtiring · robotni bosing — sessiya ochiladi",
                            "Drag to orbit · pinch to zoom · click a robot to open its session"))
                        .font(.caption).foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 10).frame(height: 26)
                        .background(Color.black.opacity(0.35), in: Capsule())
                        .padding(12)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .bottom) {
                    if let toast {
                        Text(toast).font(.callout.weight(.semibold)).padding(.horizontal, 16).frame(height: 36)
                            .background(.regularMaterial, in: Capsule())
                            .padding(12)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .allowsHitTesting(false)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            HStack(spacing: 10) {
                roomList(rooms)
                Spacer(minLength: 0)
                Button { world.home() } label: {
                    Label(tr("Butun ofis", "Whole office"), systemImage: "building.2")
                        .font(.callout.weight(.medium)).padding(.horizontal, 12).frame(height: 34)
                        .surfaceCapsule(interactive: true)
                }
                .buttonStyle(.plain).noFocusRing()
                .help(tr("Kamerani butun binoga qaytarish", "Show the whole building"))
            }
        }
        .padding(.horizontal, 24).padding(.bottom, 24)
    }

    /// Xonalar holat bo'yicha tartibda — rang ko'rmaydigan uchun ham holat yozuv bilan
    @ViewBuilder
    private func roomList(_ rooms: [OfficeRoom]) -> some View {
        if rooms.isEmpty {
            Text(tr("Bugun hech qaysi loyihada ish bo'lmadi — Claude Code ishga tushsa, robotlar shu yerda ishlaydi",
                    "No project has been active today — when Claude Code runs, robots work here"))
                .font(.callout).foregroundStyle(.secondary)
                .padding(.horizontal, 14).frame(height: 34)
                .surfaceCapsule()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(rooms) { r in
                        Button { world.focus(r.id) } label: { chip(r) }
                            .buttonStyle(.plain).noFocusRing()
                            .help(r.agents.map { "\($0.name): \($0.state.title) — \($0.what)" }.joined(separator: "\n"))
                    }
                }
                .padding(.horizontal, 2)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func chip(_ r: OfficeRoom) -> some View {
        let st = r.state
        let color: Color = st == .waiting ? Brand.warn : st == .error ? Brand.err : st.busy ? Brand.ok : .secondary
        return HStack(spacing: 8) {
            ProjectAvatar(name: r.id, size: 22)
            Text(r.id).font(.callout.weight(.semibold)).lineLimit(1)
            Text(r.status).font(.caption.weight(.semibold)).foregroundStyle(color).lineLimit(1)
            Text(Fmt.tokens(r.tokens)).font(.caption).monospacedDigit().foregroundStyle(.secondary)
        }
        .padding(.leading, 6).padding(.trailing, 12).frame(height: 34)
        .surfaceCapsule(interactive: true)
        .overlay(Capsule().strokeBorder(st == .waiting ? Brand.warn.opacity(0.7) : .clear, lineWidth: 1.5))
    }

    private func pick(_ p: OfficeSCNView.Pick) {
        switch p {
        case .bot(let id):
            guard let a = world.agent(id) else { return }
            sessionId = a.sessionId
            withAnimation(Motion.snappy) { section = .graph }
        case .room(let id):
            world.focus(id)
        case .drone:
            let r = world.watcherReport()
            if let room = r.room { world.focus(room) }
            show(r.text)
        }
    }

    private func show(_ text: String) {
        toastId += 1
        let id = toastId
        withAnimation(Motion.snappy) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            if toastId == id { withAnimation(Motion.snappy) { toast = nil } }
        }
    }
}

private struct OfficeSceneView: NSViewRepresentable {
    let world: OfficeWorld
    let rooms: [OfficeRoom]
    let still: Bool
    let onPick: (OfficeSCNView.Pick) -> Void

    func makeNSView(context: Context) -> OfficeSCNView {
        let v = OfficeSCNView(frame: .zero, options: [SCNView.Option.preferredRenderingAPI.rawValue: SCNRenderingAPI.metal.rawValue])
        v.world = world
        v.scene = world.scene
        v.pointOfView = world.cameraNode
        v.delegate = world
        v.antialiasingMode = .multisampling4X
        v.rendersContinuously = true
        v.backgroundColor = .black
        return v
    }

    func updateNSView(_ v: OfficeSCNView, context: Context) {
        v.onPick = onPick
        world.set(rooms)
        world.setStill(still)
        // Reduce Motion / yengil rejimda kamroq kadr — robotlar joyida turadi
        v.preferredFramesPerSecond = still ? 20 : 30
    }
}

/// SceneKit ko'rinishi: sudrash — aylantirish, chimdish/g'ildirak — yaqinlashtirish, ikki barmoq — surish, bosish — tanlash
final class OfficeSCNView: SCNView {
    enum Pick { case bot(String), room(String), drone }

    weak var world: OfficeWorld?
    var onPick: ((Pick) -> Void)?
    private var downAt: NSPoint?
    private var moved = false
    private var hoverAt = 0.0
    private var occlusion: NSObjectProtocol?

    override var acceptsFirstResponder: Bool { true }

    override func setFrameSize(_ size: NSSize) {
        super.setFrameSize(size)
        if size.height > 0 { world?.setAspect(size.width / size.height) }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let occlusion { NotificationCenter.default.removeObserver(occlusion) }
        occlusion = nil
        guard let window else { isPlaying = false; return }
        // Oyna ko'rinmasa (orqada, yig'ilgan) — chizish to'xtaydi
        isPlaying = window.occlusionState.contains(.visible)
        occlusion = NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main) { [weak self] _ in
            guard let self, let w = self.window else { return }
            self.isPlaying = w.occlusionState.contains(.visible)
        }
    }

    deinit { if let occlusion { NotificationCenter.default.removeObserver(occlusion) } }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: self))
    }

    override func mouseDown(with e: NSEvent) { downAt = convert(e.locationInWindow, from: nil); moved = false }

    override func mouseDragged(with e: NSEvent) {
        let p = convert(e.locationInWindow, from: nil)
        if let d = downAt, hypot(p.x - d.x, p.y - d.y) > 4 { moved = true }
        guard moved else { return }
        NSCursor.closedHand.set()
        world?.rotate(dx: e.deltaX, dy: e.deltaY)
    }

    override func rightMouseDragged(with e: NSEvent) { world?.pan(dx: e.deltaX, dy: e.deltaY) }

    override func mouseUp(with e: NSEvent) {
        defer { downAt = nil }
        if moved { NSCursor.openHand.set(); return }
        if let p = pick(at: convert(e.locationInWindow, from: nil)) { onPick?(p) }
    }

    override func scrollWheel(with e: NSEvent) {
        if e.hasPreciseScrollingDeltas {
            world?.pan(dx: e.scrollingDeltaX, dy: e.scrollingDeltaY)
        } else {
            world?.zoom(exp(-e.scrollingDeltaY * 0.08))
        }
    }

    override func magnify(with e: NSEvent) { world?.zoom(1 / (1 + e.magnification)) }

    override func rotate(with e: NSEvent) { world?.rotate(dx: CGFloat(-e.rotation) * 2, dy: 0) }

    override func mouseMoved(with e: NSEvent) {
        let now = CACurrentMediaTime()
        guard now - hoverAt > 0.06 else { return }
        hoverAt = now
        if pick(at: convert(e.locationInWindow, from: nil)) != nil { NSCursor.pointingHand.set() } else { NSCursor.openHand.set() }
    }

    /// Ustunlik: yorliq → dron → robot → xona poli
    private func pick(at p: NSPoint) -> Pick? {
        let hits = hitTest(p, options: [.searchMode: SCNHitTestSearchMode.all.rawValue, .ignoreHiddenNodes: true])
        var found: [Pick] = []
        for h in hits {
            var n: SCNNode? = h.node
            while let node = n {
                if let name = node.name {
                    if name.hasPrefix("label:") { return .room(String(name.dropFirst(6))) }
                    if name == "drone" { found.append(.drone); break }
                    if name.hasPrefix("bot:") { found.append(.bot(String(name.dropFirst(4)))); break }
                    if name.hasPrefix("room:") { found.append(.room(String(name.dropFirst(5)))); break }
                }
                n = node.parent
            }
        }
        func rank(_ p: Pick) -> Int { switch p { case .drone: return 0; case .bot: return 1; case .room: return 2 } }
        return found.min { rank($0) < rank($1) }
    }
}
