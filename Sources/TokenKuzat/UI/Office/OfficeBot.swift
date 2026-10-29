import SceneKit

// Robot-agent: oq tana, ekran-yuz (ko'zlar holatga qarab), antenna, qo'l-oyoqlar.
// Asosiy agent kattaroq va quloqchin-mikrofon taqadi — yordamchilarga topshiriq beradi.

/// Robot boradigan joy
struct BotSpot {
    enum Pose { case desk, sofa, stand, walk }
    var pose: Pose
    var pos: SCNVector3
    var rotY: CGFloat
    var desk: Int? = nil
    var seat: Int? = nil
    /// Divan va stol band — polda, devorga suyanib o'tiradi
    var floor = false
}

final class Bot {
    var a: OfficeAgent
    let g = SCNNode(), m = SCNNode(), head = SCNNode()
    let armL: (yaw: SCNNode, pivot: SCNNode), armR: (yaw: SCNNode, pivot: SCNNode)
    let legL: (yaw: SCNNode, pivot: SCNNode), legR: (yaw: SCNNode, pivot: SCNNode)
    let chest: SCNNode, tip: SCNNode, mug: SCNNode
    let faceMat: SCNMaterial
    let s0: CGFloat, col: Int, faceTint: Int
    let phase: Double
    var faceKey = ""
    var nextBlink = 0.0, blinkUntil = 0.0

    var pose: BotSpot.Pose = .stand
    var target: BotSpot, home: BotSpot
    var path: [SCNVector3] = []
    var wander: (spot: Int, until: Double)?
    var nextWander = 0.0
    var prev: OfficeState?
    var mood: (emo: OfficeArt.Emotion, t0: Double, until: Double, hop: Bool)?
    var cmd: (to: Bot, until: Double)?
    var flash = -10.0
    var bubble: SCNNode?, bubbleUntil = 0.0
    var badge: SCNNode?, badgeY: CGFloat = 0
    var ringNode: SCNNode?
    var zz: [SCNNode] = []
    var dressed: OfficeState?

    init(_ a: OfficeAgent, at spot: BotSpot, phase: Double) {
        self.a = a
        self.phase = phase
        target = spot; home = spot; pose = spot.pose
        col = a.isMain ? OfficeArt.accent : OfficeArt.helper
        faceTint = a.isMain ? 0xB3AAFF : 0x8BE6F5
        s0 = a.isMain ? 1 : 0.82
        g.addChildNode(m)
        m.scale = SCNVector3(s0, s0, s0)
        g.position = spot.pos
        g.eulerAngles.y = spot.rotY

        addNode(m, Geo.capsule(0.15, 0.16), Mat.robotWhite, 0, 0.2, 0)
        chest = addNode(m, Geo.rbox(0.1, 0.035, 0.02, 0.012), Mat.glow(col), 0, 0.24, 0.148, cast: false)
        head.position = SCNVector3(0, 0.52, 0); m.addChildNode(head)
        addNode(head, Geo.rbox(0.4, 0.31, 0.33, 0.12), Mat.robotWhite)
        addNode(head, Geo.rbox(0.31, 0.18, 0.04, 0.07), Mat.visor, 0, -0.005, 0.15, cast: false)
        faceMat = SCNMaterial()
        faceMat.lightingModel = .constant
        faceMat.blendMode = .alpha
        faceMat.writesToDepthBuffer = false
        faceMat.diffuse.intensity = 1.4
        addNode(head, Geo.plane(0.29, 0.172), faceMat, 0, -0.005, 0.1715, cast: false)
        for x in [-0.205, 0.205] as [CGFloat] {
            addNode(head, Geo.cyl(0.035, 0.035, 0.03, seg: 16), Mat.glow(col, dim: true), x, 0, 0, cast: false).eulerAngles.z = .pi / 2
        }
        addNode(head, Geo.cyl(0.012, 0.012, 0.11, seg: 8), Mat.robotJoint, 0, 0.21, 0)
        tip = addNode(head, Geo.sphere(0.032, seg: 16), Mat.glow(col), 0, 0.275, 0, cast: false)
        if a.isMain {
            // quloqchin va mikrofon
            addNode(head, Geo.arc(0.218, thick: 0.016, depth: 0.032), Mat.robotJoint)
            let p0 = SCNVector3(-0.21, -0.02, 0.02), p1 = SCNVector3(-0.09, -0.11, 0.19)
            let d = SCNVector3(p1.x - p0.x, p1.y - p0.y, p1.z - p0.z)
            let len = sqrt(d.x * d.x + d.y * d.y + d.z * d.z)
            let boom = addNode(head, Geo.cyl(0.008, 0.008, len, seg: 8), Mat.metal, (p0.x + p1.x) / 2, (p0.y + p1.y) / 2, (p0.z + p1.z) / 2, cast: false)
            boom.simdOrientation = simd_quatf(from: SIMD3(0, 1, 0), to: simd_normalize(SIMD3(Float(d.x), Float(d.y), Float(d.z))))
            addNode(head, Geo.sphere(0.02, seg: 12), Mat.glow(col), p1.x, p1.y, p1.z, cast: false)
        }
        let torso = m
        func limb(_ x: CGFloat, _ y: CGFloat, _ len: CGFloat, _ r: CGFloat) -> (SCNNode, SCNNode) {
            let yaw = SCNNode(); yaw.position = SCNVector3(x, y, 0); torso.addChildNode(yaw)
            let pivot = SCNNode(); yaw.addChildNode(pivot)
            addNode(pivot, Geo.capsule(r, len), Mat.robotWhite, 0, -len / 2 - r * 0.6, 0)
            return (yaw, pivot)
        }
        armL = limb(-0.2, 0.33, 0.15, 0.045); armR = limb(0.2, 0.33, 0.15, 0.045)
        legL = limb(-0.08, 0.02, 0.17, 0.055); legR = limb(0.08, 0.02, 0.17, 0.055)
        mug = addNode(armR.pivot, Geo.cyl(0.04, 0.035, 0.1, seg: 16), Mat.ceramic, 0, -0.22, 0.05)
        mug.eulerAngles.x = .pi / 2
        mug.isHidden = true
        g.name = "bot:" + a.id
    }

    static let emotion: [OfficeState: OfficeArt.Emotion] = [.working: .focus, .thinking: .think, .waiting: .wide, .error: .sad, .idle: .happy, .sleeping: .sleep]

    func drawFace(_ emo: OfficeArt.Emotion, lx: CGFloat, ly: CGFloat, blink: Bool) {
        let key = "\(emo.rawValue)\(blink)\(Int((lx * 20).rounded())),\(Int((ly * 20).rounded()))"
        guard key != faceKey else { return }
        faceKey = key
        faceMat.diffuse.contents = OfficeArt.face(emo, lx: lx, ly: ly, blink: blink, tint: faceTint, eyes: [-22, 22], k: 1)
    }

    // MARK: Holat belgilari

    /// «!», «×», «…», «z z», oyoq ostidagi halqa va krujka
    func dress(ring: SCNMaterial) {
        let s = a.state
        guard dressed != s else { return }
        dressed = s
        ([badge, ringNode] + zz).forEach { $0?.removeFromParentNode() }
        badge = nil; ringNode = nil; zz = []
        let dim = s == .sleeping, top: CGFloat = 1.18
        chest.geometry?.firstMaterial = Mat.glow(col, dim: dim)
        tip.geometry?.firstMaterial = Mat.glow(col, dim: dim)
        mug.isHidden = s != .idle
        switch s {
        case .waiting:
            badge = sprite(.waiting, 0.38, SCNVector3(0, top + 0.05, 0))
            let r = addNode(m, Geo.ring(0.34, 0.4), ring, 0, -0.26, 0, cast: false)
            ringNode = r
        case .error: badge = sprite(.error, 0.32, SCNVector3(0.28, top - 0.15, 0))
        case .thinking: badge = sprite(.thinking, 0.42, SCNVector3(0, top, 0))
        case .sleeping: zz = (0..<3).map { _ in sprite(.z, 0.2, SCNVector3(0, 0.9, 0)) }
        default: break
        }
        if let badge { badgeY = badge.position.y }
    }

    private static var badgeCache: [String: CGImage] = [:]

    private func sprite(_ kind: OfficeArt.Badge, _ size: CGFloat, _ at: SCNVector3) -> SCNNode {
        let key = "\(kind)"
        let img = Bot.badgeCache[key] ?? OfficeArt.badge(kind)
        Bot.badgeCache[key] = img
        let n = SCNNode(geometry: Geo.plane(size, size))
        n.geometry?.firstMaterial = Mat.overlay(img)
        n.constraints = [SCNBillboardConstraint()]
        n.renderingOrder = 90
        n.position = at
        n.castsShadow = false
        m.addChildNode(n)
        return n
    }

    func say(_ text: String, tint: Int, now: Double) {
        bubble?.removeFromParentNode()
        let n = SCNNode(geometry: Geo.plane(1.0, 0.28))
        n.geometry?.firstMaterial = Mat.overlay(OfficeArt.bubble(text, tint: tint))
        n.constraints = [SCNBillboardConstraint()]
        n.renderingOrder = 95
        n.position = SCNVector3(0, 1.5, 0)
        n.castsShadow = false
        m.addChildNode(n)
        bubble = n
        bubbleUntil = now + 2.2
    }

    // MARK: Harakat

    static let standY: CGFloat = 0.27
    /// Bo'sh robot ba'zan shu joylarga borib turadi: javon, shisha oldi, gul oldi
    static let spots: [(SCNVector3, CGFloat)] = [
        (SCNVector3(1.4, standY, -1.7), .pi),
        (SCNVector3(-1.2, standY, 1.95), 0),
        (SCNVector3(-2.05, standY, 1.55), atan2(-0.5, 0.5)),
    ]

    /// Yo'l: stollar oldidagi yo'lak va divan oldi orqali, stolcha atrofidan aylanib
    func route(to t: BotSpot) -> [SCNVector3] {
        let p = g.position
        var pts: [SCNVector3] = []
        let exit: SCNVector3? = pose == .desk ? SCNVector3(p.x, Bot.standY, -0.6)
            : pose == .sofa ? (target.floor || home.floor ? SCNVector3(p.x + 0.4, Bot.standY, p.z) : SCNVector3(1.9, Bot.standY, p.z)) : nil
        if let exit { pts.append(exit) }
        let entry = t.pose == .desk ? SCNVector3(t.pos.x, Bot.standY, -0.6)
            : t.pose == .sofa ? (t.floor ? SCNVector3(t.pos.x + 0.4, Bot.standY, t.pos.z) : SCNVector3(1.9, Bot.standY, t.pos.z)) : t.pos
        let from = exit ?? p
        if (from.x > 1.6) != (entry.x > 1.6) && (from.z > -0.3 || entry.z > -0.3) { pts.append(SCNVector3(1.9, Bot.standY, -0.45)) }
        pts.append(entry)
        if t.pose != .stand { pts.append(t.pos) }
        return pts
    }

    func go(_ t: BotSpot, still: Bool) {
        target = t
        if still { g.position = t.pos; g.eulerAngles.y = t.rotY; pose = t.pose; path = []; return }
        path = route(to: t); pose = .walk
    }

    private func walk(_ dt: Double, now: Double, rnd: inout OfficeArt.Rand) {
        guard let tgt = path.first else { return }
        let p = g.position
        let vx = tgt.x - p.x, vy = tgt.y - p.y, vz = tgt.z - p.z
        let dist = sqrt(vx * vx + vy * vy + vz * vz), sp = 1.15 * CGFloat(dt)
        let last = path.count == 1 && target.pose != .stand
        // o'tirishdan oldin orqasi bilan joyga keladi
        g.eulerAngles.y = lerpAngle(g.eulerAngles.y, last ? target.rotY : atan2(vx, vz), 1 - exp(-CGFloat(dt) * 10))
        if dist > sp {
            g.position = SCNVector3(p.x + vx * sp / dist, p.y + vy * sp / dist, p.z + vz * sp / dist)
            return
        }
        g.position = tgt
        path.removeFirst()
        if !path.isEmpty { return }
        pose = target.pose
        if wander != nil { wander?.until = now + 3.5 + Double(rnd.next()) * 2.5 }
    }

    /// Har kadr: poza, ko'zlar, belgilar. `t` — animatsiya vaqti (Reduce Motion'da 0)
    func animate(t: Double, dt: Double, now: Double, still: Bool, camera: SCNVector3, room: Room, rnd: inout OfficeArt.Rand) {
        let s = a.state, ph = t + phase
        head.eulerAngles = SCNVector3Zero; head.position.y = 0.52
        for l in [armL, armR, legL, legR] { l.yaw.eulerAngles = SCNVector3Zero; l.pivot.eulerAngles = SCNVector3Zero }
        m.position.y = 0; m.eulerAngles.z = 0; m.scale = SCNVector3(s0, s0, s0)
        var lx: CGFloat = 0, ly: CGFloat = 0
        func sn(_ x: Double) -> CGFloat { CGFloat(sin(x)) }

        if !path.isEmpty {
            walk(dt, now: now, rnd: &rnd)
            let w = sn(now * 9 + phase)
            legL.pivot.eulerAngles.x = w * 0.55; legR.pivot.eulerAngles.x = -w * 0.55
            armL.pivot.eulerAngles.x = -w * 0.4; armR.pivot.eulerAngles.x = s == .idle ? -1.05 : w * 0.4
            m.position.y = abs(w) * 0.025
        } else {
            g.eulerAngles.y = lerpAngle(g.eulerAngles.y, target.rotY, 1 - exp(-CGFloat(dt) * 6))
            if pose == .desk || pose == .sofa { legL.pivot.eulerAngles.x = -.pi / 2; legR.pivot.eulerAngles.x = -.pi / 2 }
            if pose == .desk {
                armL.pivot.eulerAngles.x = -1.2; armR.pivot.eulerAngles.x = -1.2
                if s == .working {
                    armL.pivot.eulerAngles.x = -1.2 + sn(ph * 16) * 0.1; armR.pivot.eulerAngles.x = -1.2 + sn(ph * 16 + .pi) * 0.1
                    head.position.y = 0.52 + sn(ph * 2) * 0.006; ly = 0.45
                }
                if s == .thinking { // qo'li iyagida, yuqoriga qarab o'ylaydi
                    head.eulerAngles.y = sn(ph * 0.8) * 0.25; head.eulerAngles.x = -0.14; armR.pivot.eulerAngles.x = -2.3
                    lx = sn(ph * 0.8) * 0.6; ly = -0.55
                }
                if s == .error { // stoldan o'girilib, boshini qashiydi
                    head.eulerAngles.x = 0.28; head.eulerAngles.z = sn(ph * 1.4) * 0.12
                    armR.pivot.eulerAngles.x = -2.75; armR.pivot.eulerAngles.z = -0.25 + sn(ph * 9) * 0.08; armL.pivot.eulerAngles.x = -0.4
                    lx = sn(ph * 1.4) * 0.3; ly = 0.35
                }
                if s == .idle { lx = sn(ph * 0.35) * 0.4 }
                if s == .sleeping { // boshini stolga qo'yib uxlaydi
                    head.eulerAngles.x = 0.45; head.eulerAngles.z = 0.2
                    m.scale.y = s0 * (1 + sn(ph * 1.3) * 0.015)
                }
            }
            if pose == .sofa {
                armL.pivot.eulerAngles.x = -0.3
                if s == .idle { armR.pivot.eulerAngles.x = -1.05 - 0.45 * max(0, sn(ph * 0.6)); lx = sn(ph * 0.35) * 0.4 }
                if s == .sleeping {
                    head.eulerAngles.z = 0.38; head.eulerAngles.x = 0.15
                    m.scale.y = s0 * (1 + sn(ph * 1.3) * 0.015)
                }
            }
            if pose == .stand {
                if s == .waiting { // sizga qaraydi va qo'l silkitadi
                    armR.pivot.eulerAngles.z = 2.55 + sn(ph * 6) * 0.35
                    let v = g.convertPosition(camera, from: nil)
                    head.eulerAngles.y = clamp(atan2(v.x, v.z), -0.9, 0.9); head.eulerAngles.x = -0.22; ly = -0.3
                } else if s == .idle { // krujka bilan turib, atrofga qaraydi
                    armR.pivot.eulerAngles.x = -1.05; head.eulerAngles.x = -0.1; head.eulerAngles.y = sn(ph * 0.5) * 0.35
                    m.eulerAngles.z = sn(ph * 0.9) * 0.02; lx = sn(ph * 0.5) * 0.5
                }
            }
        }
        // buyruq: asosiy agent yordamchiga o'girilib, qo'li bilan ko'rsatadi
        if let c = cmd, now < c.until {
            let v = g.convertPosition(c.to.g.worldPosition, from: nil)
            let yaw = atan2(v.x, v.z)
            head.eulerAngles.y = clamp(yaw, -1.1, 1.1); lx = clamp(yaw, -1, 1) * 0.6; ly = 0
            let arm = v.x > 0 ? armR : armL
            arm.yaw.eulerAngles.y = clamp(yaw, -1.6, 1.6)
            arm.pivot.eulerAngles = SCNVector3(-.pi / 2 - 0.15, 0, 0)
        }
        // o'tkinchi kayfiyat: ish tugadi — xursand sakraydi
        let md = mood.flatMap { now < $0.until ? $0 : nil }
        if let md, md.hop, !still {
            m.position.y += max(0, sn((now - md.t0) * 11)) * 0.07 * max(0, 1 - CGFloat(now - md.t0) / 0.9)
        }
        if now > nextBlink { blinkUntil = now + 0.13; nextBlink = now + 2.4 + Double(rnd.next()) * 3.2 }
        drawFace(md?.emo ?? Bot.emotion[s] ?? .happy, lx: lx, ly: ly, blink: now < blinkUntil)

        // bo'sh robot ba'zan turib yuradi (xonada e'tibor kerak bo'lmasa)
        if !still && s == .idle && path.isEmpty {
            if let w = wander {
                if pose == .stand && w.until > 0 && now > w.until { wander = nil; go(home, still: false) }
            } else if pose == .sofa && room.outline.isHidden {
                if nextWander == 0 { nextWander = now + 7 + Double(rnd.next()) * 9 }
                if now > nextWander {
                    let taken = room.bots.values.compactMap { $0.wander?.spot }
                    let free = Bot.spots.indices.filter { !taken.contains($0) }
                    if !free.isEmpty {
                        let k = free[min(free.count - 1, Int(rnd.next() * CGFloat(free.count)))]
                        wander = (k, 0)
                        go(BotSpot(pose: .stand, pos: Bot.spots[k].0, rotY: Bot.spots[k].1), still: false)
                    }
                    nextWander = 0
                }
            }
        }
        badge?.position.y = badgeY + sn(ph * 2.2) * 0.03
        if let r = ringNode { let k = 1 + 0.12 * sn(t * 3); r.scale = SCNVector3(k, 1, k) }
        for (k, z) in zz.enumerated() {
            let q = CGFloat((ph * 0.35 + Double(k) / 3).truncatingRemainder(dividingBy: 1))
            z.position = SCNVector3(0.15 + q * 0.25, 0.85 + q * 0.5, 0)
            z.opacity = sin(q * .pi) * 0.9
        }
        let fl = max(0, 1 - CGFloat(now - flash) / 0.6)
        let tk = 1 + (s.busy ? 0.25 * sn(ph * 4) : 0) + fl
        tip.scale = SCNVector3(tk, tk, tk)
        if let b = bubble {
            let left = bubbleUntil - now
            if left < 0 { b.removeFromParentNode(); bubble = nil } else { b.opacity = min(1, CGFloat(left) / 0.35) }
        }
    }
}

func lerpAngle(_ a: CGFloat, _ b: CGFloat, _ k: CGFloat) -> CGFloat {
    let d = (((b - a + .pi).truncatingRemainder(dividingBy: 2 * .pi)) + 2 * .pi).truncatingRemainder(dividingBy: 2 * .pi) - .pi
    return a + d * k
}

func clamp(_ x: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { max(lo, min(hi, x)) }
