import SceneKit
import TokenKuzatCore

// Ofis sahnasini boshqaradi: holatni robotlarga o'tkazadi, har kadr harakatlantiradi, kamera va kuzatuvchi dron.
// Sahna faqat chizish oqimida (renderer delegate) o'zgaradi; asosiy oqim `lock` ostida so'rov qoldiradi.

final class OfficeWorld: NSObject, ObservableObject, SCNSceneRendererDelegate {
    let scene = SCNScene()
    private let root = SCNNode()
    let cameraNode = SCNNode()
    private let sun = SCNNode(), ambient = SCNNode()
    private var gardens: [SCNNode] = []
    private var rooms: [String: Room] = [:]
    private let drone = Drone()
    private var packets: [Packet] = []
    private var rnd = OfficeArt.Rand(seed: 99)
    private let lock = NSLock()

    // asosiy oqimdan keladi
    private var pending: [OfficeRoom]?
    private var lastSent: [OfficeRoom]?
    private var stillMode = false
    private var aspect: CGFloat = 1.6
    /// Foydalanuvchi kamerani o'zi surmagan bo'lsa — oyna o'lchami o'zgarganda butun bino qayta sig'diriladi
    private var userMoved = false

    // kamera: nishon atrofida aylanadi
    private struct Orbit { var target: SCNVector3; var dist: CGFloat; var polar: CGFloat; var az: CGFloat }
    private var orbit = Orbit(target: SCNVector3(0, 0, 0.4), dist: 22, polar: 0.84, az: -0.3)
    private var fly: (from: Orbit, to: Orbit, t0: Double, d: Double)?
    private var flyRequest: Orbit?

    private var lastFrame = 0.0
    private var skyAt = Date.distantPast
    private var night = false
    private var synced = false

    override init() {
        super.init()
        scene.rootNode.addChildNode(root)
        Office.building(root)
        gardens = Office.slots.indices.map { i in
            let g = Office.garden(i); g.isHidden = true; root.addChildNode(g); return g
        }
        root.addChildNode(drone.g)
        root.addChildNode(drone.beam)
        root.addChildNode(drone.spot)

        let cam = SCNCamera()
        cam.fieldOfView = 30
        cam.zNear = 0.5; cam.zFar = 200
        cam.wantsHDR = true
        cam.wantsExposureAdaptation = false
        cam.bloomIntensity = 0.35; cam.bloomThreshold = 1.0; cam.bloomBlurRadius = 6
        cam.screenSpaceAmbientOcclusionIntensity = 0.9
        cam.screenSpaceAmbientOcclusionRadius = 0.45
        cam.screenSpaceAmbientOcclusionBias = 0.03
        cameraNode.camera = cam
        scene.rootNode.addChildNode(cameraNode)

        let s = SCNLight()
        s.type = .directional
        s.castsShadow = true
        s.shadowMapSize = CGSize(width: 2048, height: 2048)
        s.shadowSampleCount = 8
        s.shadowRadius = 2.5
        s.shadowColor = NSColor(white: 0, alpha: 0.55)
        s.automaticallyAdjustsShadowProjection = true
        s.maximumShadowDistance = 70
        s.shadowBias = 0.04
        sun.light = s
        scene.rootNode.addChildNode(sun)
        let a = SCNLight(); a.type = .ambient
        ambient.light = a
        scene.rootNode.addChildNode(ambient)
        applySky(Date())
        placeCamera()
    }

    // MARK: Asosiy oqimdan

    func set(_ list: [OfficeRoom]) {
        lock.lock(); defer { lock.unlock() }
        if list == lastSent { return }
        lastSent = list
        pending = list
    }

    func setStill(_ on: Bool) { lock.lock(); stillMode = on; lock.unlock() }

    func setAspect(_ a: CGFloat) {
        lock.lock(); defer { lock.unlock() }
        guard a.isFinite, a > 0 else { return }
        aspect = a
        if !userMoved { orbit = homeOrbit(); fly = nil }
    }

    func home() { lock.lock(); userMoved = false; flyRequest = homeOrbit(); lock.unlock() }

    func focus(_ roomId: String) {
        lock.lock(); defer { lock.unlock() }
        guard let r = rooms[roomId] else { return }
        userMoved = true
        flyRequest = Orbit(target: r.center, dist: 11.5, polar: 0.82, az: -0.35)
    }

    /// Sichqoncha bilan aylantirish (piksellarda)
    func rotate(dx: CGFloat, dy: CGFloat) {
        lock.lock(); defer { lock.unlock() }
        fly = nil; userMoved = true
        orbit.az -= dx * 0.008
        orbit.polar = clamp(orbit.polar - dy * 0.008, 0.25, 1.12)
    }

    func zoom(_ factor: CGFloat) {
        lock.lock(); defer { lock.unlock() }
        fly = nil; userMoved = true
        orbit.dist = clamp(orbit.dist * factor, 7, 46)
    }

    /// Ikki barmoq bilan surish — nishon pol bo'ylab siljiydi
    func pan(dx: CGFloat, dy: CGFloat) {
        lock.lock(); defer { lock.unlock() }
        fly = nil; userMoved = true
        let k = orbit.dist * 0.0016
        let rx = cos(orbit.az), rz = -sin(orbit.az)       // o'ngga
        let fx = -sin(orbit.az), fz = -cos(orbit.az)      // oldinga (kameradan uzoqqa)
        orbit.target.x = clamp(orbit.target.x - (dx * rx - dy * fx) * k, -12, 12)
        orbit.target.z = clamp(orbit.target.z - (dx * rz - dy * fz) * k, -8, 9)
    }

    /// Bosilgan robot qaysi agent
    func agent(_ botId: String) -> OfficeAgent? {
        lock.lock(); defer { lock.unlock() }
        for r in rooms.values { if let b = r.bots[botId] { return b.a } }
        return nil
    }

    /// Kuzatuvchi bosilganda: e'tibor kerak xonalar va kamera boradigan xona
    func watcherReport() -> (text: String, room: String?) {
        lock.lock(); defer { lock.unlock() }
        let list = alerts()
        var seen = Set<String>(), parts: [String] = []
        for (r, b) in list where seen.insert(r.id).inserted {
            parts.append("\(r.id) " + (b.a.state == .waiting ? tr("sizni kutyapti", "is waiting for you") : tr("xato", "has an error")))
        }
        let text = tr("Kuzatuvchi", "Watcher") + " · " + (parts.isEmpty ? tr("hammasi joyida", "all good") : parts.joined(separator: ", "))
        return (text, drone.focus?.room ?? list.first?.0.id)
    }

    private func homeOrbit() -> Orbit {
        // bino kengligi (~21 m) ekranga sig'adigan masofa; vertikal ko'rish burchagi 30°
        if aspect > 1.15 { return Orbit(target: SCNVector3(0, 0, 0.4), dist: clamp(10.5 / (tan(.pi / 12) * aspect), 20, 40), polar: 0.84, az: -0.3) }
        return Orbit(target: SCNVector3(0, 0, 0), dist: clamp(35 / max(aspect, 0.6), 30, 46), polar: 0.7, az: -1.25) // tor oynada bino bo'yiga burilib turadi
    }

    // MARK: Har kadr

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        let now = time
        let dt = min(0.05, lastFrame == 0 ? 0.016 : now - lastFrame)
        lastFrame = now
        let still = stillMode
        let t = still ? 0 : now

        if Date().timeIntervalSince(skyAt) > 60 { applySky(Date()) }
        if let list = pending { pending = nil; apply(list, now: now, still: still) }
        if let to = flyRequest {
            flyRequest = nil
            fly = (orbit, to, now, still ? 0 : 0.7)
        }
        if let f = fly {
            let k = f.d > 0 ? min(1, (now - f.t0) / f.d) : 1, e = CGFloat(1 - pow(1 - k, 3))
            orbit = Orbit(target: mix(f.from.target, f.to.target, e), dist: f.from.dist + (f.to.dist - f.from.dist) * e,
                          polar: f.from.polar + (f.to.polar - f.from.polar) * e, az: lerpAngle(f.from.az, f.to.az, e))
            if k >= 1 { fly = nil }
        }
        placeCamera()
        let cam = cameraNode.worldPosition

        let pulse = 0.55 + 0.4 * sin(CGFloat(t) * 3)
        for r in rooms.values {
            r.ring.transparency = pulse
            for b in r.bots.values { b.animate(t: t, dt: dt, now: now, still: still, camera: cam, room: r, rnd: &rnd) }
            // yorliq ekranda bir xil o'lchamda ko'rinsin
            let lp = r.label.worldPosition
            let d = sqrt(pow(cam.x - lp.x, 2) + pow(cam.y - lp.y, 2) + pow(cam.z - lp.z, 2))
            let s = d / 14
            r.label.scale = SCNVector3(s, s, s)
        }
        animatePackets(now)
        animateDrone(t: t, dt: dt, now: now, still: still, camera: cam)
    }

    private func placeCamera() {
        let o = orbit
        cameraNode.position = SCNVector3(o.target.x + o.dist * sin(o.polar) * sin(o.az), o.target.y + o.dist * cos(o.polar),
                                         o.target.z + o.dist * sin(o.polar) * cos(o.az))
        cameraNode.look(at: o.target, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
    }

    private func applySky(_ date: Date) {
        skyAt = date
        let s = Office.sky(at: date)
        night = s.night
        scene.background.contents = OfficeArt.color(s.bg)
        scene.fogColor = OfficeArt.color(s.bg)
        scene.fogStartDistance = 38; scene.fogEndDistance = 75
        scene.lightingEnvironment.contents = OfficeArt.environment(sky: s.sky, ground: s.ground)
        scene.lightingEnvironment.intensity = s.env
        ambient.light?.color = OfficeArt.color(s.sky)
        ambient.light?.intensity = s.ambient
        sun.light?.color = OfficeArt.color(s.sun)
        sun.light?.intensity = s.sunI
        sun.position = s.pos
        sun.look(at: SCNVector3(0, 0, 0))
        cameraNode.camera?.exposureOffset = s.exposure
        if synced { rooms.values.forEach { light($0) } }
    }

    // MARK: Holat → sahna

    private func apply(_ list: [OfficeRoom], now: Double, still: Bool) {
        let ids = Set(list.map(\.id))
        for (id, r) in rooms where !ids.contains(id) { r.node.removeFromParentNode(); rooms[id] = nil }
        var used = Set(rooms.values.map(\.slot))
        for r in list where rooms[r.id] == nil {
            guard let s = Office.slots.indices.first(where: { !used.contains($0) }) else { continue }
            used.insert(s)
            let room = Room(r, slot: s)
            root.addChildNode(room.node)
            rooms[r.id] = room
        }
        for (i, g) in gardens.enumerated() { g.isHidden = used.contains(i) }
        for r in list { if let room = rooms[r.id] { sync(room, r, now: now, still: still) } }
        synced = true
    }

    /// Stol va divandagi joy saqlanadi: o'tirgan robot o'z joyida qoladi, holat o'zgarsa yangi joyga yurib boradi
    private func sync(_ o: Room, _ r: OfficeRoom, now: Double, still: Bool) {
        o.data = r
        var deskOf: [String: Int] = [:], used = Set<Int>()
        let wantDesk = r.agents.filter(\.state.atDesk)
        for a in wantDesk { if let k = o.bots[a.id]?.home.desk, !used.contains(k) { deskOf[a.id] = k; used.insert(k) } }
        for a in wantDesk where deskOf[a.id] == nil {
            if let k = o.desks.indices.first(where: { !used.contains($0) }) { deskOf[a.id] = k; used.insert(k) }
        }
        var seatOf: [String: Int] = [:], seats = Set<Int>()
        let lounge = r.agents.filter { !$0.state.atDesk && $0.state != .waiting }
        for a in lounge { if let k = o.bots[a.id]?.home.seat, !seats.contains(k) { seatOf[a.id] = k; seats.insert(k) } }
        for a in lounge where seatOf[a.id] == nil {
            if let k = (0..<2).first(where: { !seats.contains($0) }) { seatOf[a.id] = k; seats.insert(k) }
        }
        // divanda joy qolmasa — bo'sh stol stuliga o'tiradi (monitor o'chiq)
        for a in lounge where seatOf[a.id] == nil && deskOf[a.id] == nil {
            if let k = o.desks.indices.first(where: { !used.contains($0) }) { deskOf[a.id] = k; used.insert(k) }
        }
        // stol ham band bo'lsa — polda, chap devorga suyanib
        var floorOf: [String: Int] = [:]
        for a in lounge where seatOf[a.id] == nil && deskOf[a.id] == nil && floorOf.count < 2 { floorOf[a.id] = floorOf.count }
        var wi: CGFloat = 0
        func target(_ a: OfficeAgent) -> BotSpot {
            if let k = deskOf[a.id] {
                return BotSpot(pose: .desk, pos: o.desks[k].seat, rotY: a.state == .error ? .pi * 0.55 : .pi, desk: k)
            }
            if let k = seatOf[a.id] {
                return BotSpot(pose: .sofa, pos: SCNVector3(2.36, 0.53, 0.55 + CGFloat(k) * 0.9), rotY: -.pi / 2, seat: k)
            }
            if let k = floorOf[a.id] {
                return BotSpot(pose: .sofa, pos: SCNVector3(-2.62, 0.1, 0.5 + CGFloat(k) * 0.75), rotY: .pi / 2, floor: true)
            }
            defer { wi += 1 }
            return BotSpot(pose: .stand, pos: SCNVector3(-0.85 + wi * 0.7, Bot.standY, -0.2), rotY: 0)
        }

        let ids = Set(r.agents.map(\.id))
        for (id, b) in o.bots where !ids.contains(id) { b.g.removeFromParentNode(); o.bots[id] = nil }
        for a in r.agents {
            let t = target(a)
            if let b = o.bots[a.id] {
                b.a = a
                let same = b.home.pose == t.pose && dist(b.home.pos, t.pos) < 0.05
                b.home = t
                if !same { b.wander = nil; b.go(t, still: still) }
                else if b.wander == nil { b.target = t }
            } else {
                let b = Bot(a, at: t, phase: Double(rnd.next()) * 10)
                o.node.addChildNode(b.g)
                o.bots[a.id] = b
            }
            o.bots[a.id]?.dress(ring: o.ring)
        }

        // topshiriq va hisobot: yordamchi ishga tushsa — asosiy agentdan, tugatsa — unga qaytadi
        for b in o.bots.values {
            let s = b.a.state
            let lead = b.a.isMain ? nil : o.bots.values.first { $0.a.isMain && $0.a.sessionId == b.a.sessionId }
            if let p = b.prev, p != s {
                if p.busy && s == .idle { b.mood = (.happy, now, now + 2.4, true) }
                if let lead, !p.busy, s.busy { handoff(lead, b, cmd: true, now: now, still: still) }
                if let lead, p.busy, s == .idle { handoff(b, lead, cmd: false, now: now, still: still) }
            } else if b.prev == nil, synced, let lead, s.busy {
                handoff(lead, b, cmd: true, now: now, still: still) // yangi yordamchi hozirgina chaqirildi
            }
            b.prev = s
        }
        for (k, d) in o.desks.enumerated() {
            let a = deskOf.first { $0.value == k }.flatMap { e in r.agents.first { $0.id == e.key } }
            d.show(a?.state, tool: a?.tool, night: night)
        }
        o.outline.isHidden = !r.agents.contains { $0.state == .waiting }
        light(o)
        o.updateLabel()
    }

    /// Hech kim ishlamasa xona chirog'i o'chadi; kechasi kuchliroq
    private func light(_ o: Room) {
        let lit = o.data.agents.contains { $0.state != .sleeping }
        o.light.light?.intensity = lit ? (night ? 40 : 15) : 0
        o.lamp.light?.intensity = lit ? (night ? 45 : 15) : 0
        o.shade.emission.intensity = lit ? 1.6 : 0
    }

    private func dist(_ a: SCNVector3, _ b: SCNVector3) -> CGFloat { sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2) + pow(a.z - b.z, 2)) }
    private func mix(_ a: SCNVector3, _ b: SCNVector3, _ k: CGFloat) -> SCNVector3 {
        SCNVector3(a.x + (b.x - a.x) * k, a.y + (b.y - a.y) * k, a.z + (b.z - a.z) * k)
    }

    // MARK: Topshiriq kartasi

    private struct Packet { let card: SCNNode; let from: Bot; let to: Bot; let cmd: Bool; let t0: Double; let d: Double }
    private static let cardGeo = Geo.rbox(0.17, 0.11, 0.02, 0.02)
    private static let halo = [true: OfficeArt.glow(OfficeArt.accent), false: OfficeArt.glow(OfficeArt.ok)]

    /// Asosiy agent yordamchiga topshiriq kartasini uchiradi; yordamchi natijani qaytaradi
    private func handoff(_ from: Bot, _ to: Bot, cmd: Bool, now: Double, still: Bool) {
        from.say(cmd ? "→ \(to.a.name)" : tr("✓ Tayyor", "✓ Done"), tint: cmd ? OfficeArt.accent : OfficeArt.ok, now: now)
        if cmd { from.cmd = (to, now + 1.9) }
        if still { return }
        let card = SCNNode(geometry: Self.cardGeo.copy() as? SCNGeometry)
        card.geometry?.firstMaterial = Mat.glow(cmd ? OfficeArt.accent : OfficeArt.ok)
        card.castsShadow = false
        let halo = SCNNode(geometry: Geo.plane(0.55, 0.55))
        halo.geometry?.firstMaterial = Mat.overlay(Self.halo[cmd], additive: true)
        halo.constraints = [SCNBillboardConstraint()]
        card.addChildNode(halo)
        card.isHidden = true
        root.addChildNode(card)
        packets.append(Packet(card: card, from: from, to: to, cmd: cmd, t0: now + 0.45, d: 1.15))
    }

    private func animatePackets(_ now: Double) {
        packets.removeAll { pk in
            let k = (now - pk.t0) / pk.d
            pk.card.isHidden = k < 0
            if k < 0 { return false }
            var a = pk.from.g.worldPosition, b = pk.to.g.worldPosition
            a.y += 0.95; b.y += 0.95
            let e = CGFloat(min(1, k)), s = e * e * (3 - 2 * e)
            var p = mix(a, b, s)
            p.y += sin(e * .pi) * 0.9
            pk.card.position = p
            pk.card.eulerAngles = SCNVector3(0.4, e * .pi * 2, 0)
            guard k >= 1 else { return false }
            pk.card.removeFromParentNode()
            pk.to.flash = now
            pk.to.mood = pk.cmd ? (.wide, now, now + 0.9, false) : (.happy, now, now + 1.8, false)
            return true
        }
    }

    // MARK: Kuzatuvchi dron

    /// Ruxsat kutayotgan va xato bergan robotlar, muhimi birinchi
    private func alerts() -> [(Room, Bot)] {
        rooms.values.sorted { $0.slot < $1.slot }
            .flatMap { r in r.bots.values.filter { $0.a.state == .waiting || $0.a.state == .error }.map { (r, $0) } }
            .sorted { $0.1.a.state < $1.1.a.state }
    }

    private func animateDrone(t: Double, dt: Double, now: Double, still: Bool, camera: SCNVector3) {
        let d = drone, list = alerts()
        var goal: SCNVector3
        if !list.isEmpty {
            // bir nechta xona bo'lsa — navbat bilan, har biriga 5 soniya
            let current = list.firstIndex { $0.1.a.id == d.focus?.bot }
            if now > d.nextSwitch || current == nil { d.idx = (d.idx + 1) % list.count; d.nextSwitch = now + 5 }
            let f = list[d.idx % list.count]
            d.focus = (f.0.id, f.1.a.id, f.1.a.state)
            goal = f.1.g.worldPosition
            goal.y = 2.9
        } else {
            d.focus = nil
            goal = SCNVector3(sin(t * 0.11) * 8.6, 3.3, 0.3 + sin(t * 0.22) * 1.4) // yo'lak ustida aylanib yuradi
        }
        let prev = d.g.position
        let k = still ? 1 : 1 - exp(-CGFloat(dt) * 1.4)
        d.g.position = mix(prev, goal, k)
        let p = d.g.position
        let vx = (p.x - prev.x) / max(CGFloat(dt), 0.001), vz = (p.z - prev.z) / max(CGFloat(dt), 0.001)
        d.body.position.y = still ? 0 : sin(CGFloat(now) * 2.1) * 0.05
        d.body.eulerAngles.z = clamp(-vx * 0.07, -0.3, 0.3)
        d.body.eulerAngles.x = clamp(vz * 0.07, -0.3, 0.3)
        d.g.eulerAngles.y = lerpAngle(d.g.eulerAngles.y, atan2(camera.x - p.x, camera.z - p.z), 1 - exp(-CGFloat(dt) * 3))
        if !still { for (i, r) in d.rotors.enumerated() { r.eulerAngles.y += CGFloat(dt) * (i % 2 == 1 ? 22 : -22) } }
        let kind = d.focus?.state
        let hex = kind == .waiting ? OfficeArt.warn : kind == .error ? OfficeArt.err : OfficeArt.helper
        d.ringMat.diffuse.contents = OfficeArt.color(hex)
        let near = sqrt(pow(p.x - goal.x, 2) + pow(p.y - goal.y, 2) + pow(p.z - goal.z, 2)) < 0.9
        let on: CGFloat = d.focus != nil && near ? 0.5 : 0
        d.beamOpacity += (on - d.beamOpacity) * (1 - exp(-CGFloat(dt) * 5))
        d.beamMat.multiply.contents = OfficeArt.color(hex)
        d.beam.opacity = d.beamOpacity
        let by = p.y + d.body.position.y - 0.22
        d.beam.position = SCNVector3(p.x, by, p.z)
        d.beam.scale = SCNVector3(1, by - 0.12, 1)
        d.spot.position = SCNVector3(p.x, by, p.z)
        d.spot.light?.color = OfficeArt.color(hex)
        d.spot.light?.intensity = d.beamOpacity * 2600
        d.faceTint = kind == .waiting ? OfficeArt.warn : kind == .error ? OfficeArt.err : 0x8BE6F5
        if now > d.nextBlink { d.blinkUntil = now + 0.14; d.nextBlink = now + 2.8 + Double(rnd.next()) * 2.5 }
        let emo: OfficeArt.Emotion = kind == .waiting ? .wide : kind == .error ? .sad : .focus
        d.drawFace(emo, lx: d.focus != nil ? 0 : sin(CGFloat(t) * 0.7) * 0.8, ly: d.focus != nil ? 0.6 : 0, blink: now < d.blinkUntil)
    }
}

/// Kuzatuvchi — TokenKuzat'ning o'zi, agent emas: yo'lak ustida aylanadi, e'tibor kerak bo'lsa o'sha robotga nur tushiradi
final class Drone {
    let g = SCNNode(), body = SCNNode()
    let ringMat = Mat.glow(OfficeArt.helper)
    var rotors: [SCNNode] = []
    let beam: SCNNode, beamMat: SCNMaterial
    let spot = SCNNode()
    let faceMat = SCNMaterial()
    var faceKey = "", faceTint = 0x8BE6F5
    var beamOpacity: CGFloat = 0
    var idx = -1, nextSwitch = 0.0
    var focus: (room: String, bot: String, state: OfficeState)?
    var nextBlink = 0.0, blinkUntil = 0.0

    init() {
        g.position = SCNVector3(0, 3.3, 0.3)
        g.name = "drone"
        body.scale = SCNVector3(1.35, 1.35, 1.35)
        g.addChildNode(body)
        addNode(body, Geo.sphere(0.3, seg: 32), Mat.robotWhite).scale = SCNVector3(1, 0.78, 1)
        let torus = SCNTorus(ringRadius: 0.305, pipeRadius: 0.03)
        addNode(body, torus, ringMat, 0, -0.02, 0, cast: false)
        addNode(body, Geo.rbox(0.34, 0.2, 0.05, 0.06), Mat.visor, 0, 0.03, 0.28, cast: false)
        faceMat.lightingModel = .constant
        faceMat.blendMode = .alpha
        faceMat.writesToDepthBuffer = false
        faceMat.diffuse.intensity = 1.4
        addNode(body, Geo.plane(0.31, 0.184), faceMat, 0, 0.03, 0.307, cast: false)
        for r in [CGFloat.pi / 4, -.pi / 4] { addNode(body, Geo.box(0.95, 0.03, 0.04), Mat.graphite, 0, 0.13, 0).eulerAngles.y = r }
        let blur = Mat.overlay(OfficeArt.color(0xFFFFFF, 0.14))
        blur.readsFromDepthBuffer = true
        let frame = body
        rotors = [(1, 1), (1, -1), (-1, 1), (-1, -1)].map { (sx: CGFloat, sz: CGFloat) -> SCNNode in
            let hub = SCNNode(); hub.position = SCNVector3(sx * 0.335, 0.16, sz * 0.335); frame.addChildNode(hub)
            addNode(hub, Geo.cyl(0.035, 0.035, 0.05, seg: 12), Mat.graphite)
            let disc = SCNCylinder(radius: 0.19, height: 0.002); disc.radialSegmentCount = 32
            addNode(hub, disc, blur, 0, 0.03, 0, cast: false)
            for r in [0, CGFloat.pi / 2] { addNode(hub, Geo.box(0.36, 0.008, 0.035), Mat.graphite, 0, 0.03, 0, cast: false).eulerAngles.y = r }
            return hub
        }
        // nur konusi: uchi dronda, asosi polda
        let cone = SCNCone(topRadius: 0, bottomRadius: 0.75, height: 1); cone.radialSegmentCount = 40
        beamMat = Mat.overlay(OfficeArt.beam(), additive: true)
        beamMat.readsFromDepthBuffer = true
        beamMat.multiply.contents = OfficeArt.color(OfficeArt.warn)
        beam = SCNNode(geometry: cone)
        beam.geometry?.firstMaterial = beamMat
        beam.pivot = SCNMatrix4MakeTranslation(0, 0.5, 0)
        beam.castsShadow = false
        beam.opacity = 0
        let l = SCNLight(); l.type = .spot; l.intensity = 0
        l.spotInnerAngle = 18; l.spotOuterAngle = 40
        l.attenuationEndDistance = 7; l.attenuationFalloffExponent = 1.5
        spot.light = l
        spot.eulerAngles.x = -.pi / 2
        g.enumerateChildNodes { n, _ in n.name = "drone" }
    }

    func drawFace(_ emo: OfficeArt.Emotion, lx: CGFloat, ly: CGFloat, blink: Bool) {
        let key = "\(emo.rawValue)\(blink)\(Int((lx * 20).rounded())),\(Int((ly * 20).rounded()))\(faceTint)"
        guard key != faceKey else { return }
        faceKey = key
        faceMat.diffuse.contents = OfficeArt.face(emo, lx: lx, ly: ly, blink: blink, tint: faceTint, eyes: [0], k: 1.45)
    }
}
