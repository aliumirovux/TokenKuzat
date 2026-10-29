import SceneKit

// Ofis binosi: bitta qavat, 6 xona (har biri — loyiha), yo'lak, tashqarida maysa va daraxtlar.
// O'lchamlar metrda; Y — tepaga, kamera janubdan (+Z) qaraydi.

enum Geo {
    static func box(_ w: CGFloat, _ h: CGFloat, _ d: CGFloat, r: CGFloat = 0) -> SCNGeometry {
        let b = SCNBox(width: w, height: h, length: d, chamferRadius: min(r, w / 2, h / 2, d / 2))
        if r > 0 { b.chamferSegmentCount = 3 }
        return b
    }
    /// Burchaklari yumaloq quti (asosiy mebel)
    static func rbox(_ w: CGFloat, _ h: CGFloat, _ d: CGFloat, _ r: CGFloat = 0.03) -> SCNGeometry { box(w, h, d, r: r) }
    static func cyl(_ top: CGFloat, _ bottom: CGFloat, _ h: CGFloat, seg: Int = 24) -> SCNGeometry {
        if top == bottom {
            let c = SCNCylinder(radius: top, height: h); c.radialSegmentCount = seg; return c
        }
        let c = SCNCone(topRadius: top, bottomRadius: bottom, height: h); c.radialSegmentCount = seg; return c
    }
    static func capsule(_ r: CGFloat, _ len: CGFloat) -> SCNGeometry {
        let c = SCNCapsule(capRadius: r, height: len + 2 * r); c.radialSegmentCount = 16; c.capSegmentCount = 8; return c
    }
    static func sphere(_ r: CGFloat, seg: Int = 24) -> SCNGeometry {
        let s = SCNSphere(radius: r); s.segmentCount = seg; return s
    }
    static func plane(_ w: CGFloat, _ h: CGFloat) -> SCNGeometry { SCNPlane(width: w, height: h) }
    /// Tekis halqa (polda)
    static func ring(_ inner: CGFloat, _ outer: CGFloat) -> SCNGeometry {
        let t = SCNTube(innerRadius: inner, outerRadius: outer, height: 0.004); t.radialSegmentCount = 40; return t
    }
    /// Yarim halqa — quloqchin kamari (XY tekisligida, tepaga qaragan)
    static func arc(_ radius: CGFloat, thick: CGFloat, depth: CGFloat) -> SCNGeometry {
        let p = NSBezierPath()
        p.appendArc(withCenter: .zero, radius: radius + thick, startAngle: 0, endAngle: 180)
        p.appendArc(withCenter: .zero, radius: radius - thick, startAngle: 180, endAngle: 0, clockwise: true)
        p.close()
        p.flatness = 0.002
        let s = SCNShape(path: p, extrusionDepth: depth); s.chamferRadius = 0
        return s
    }
}

enum Mat {
    static func std(_ hex: Int, rough: CGFloat = 0.85, metal: CGFloat = 0, map: Any? = nil, scale: (CGFloat, CGFloat)? = nil,
                    double: Bool = false) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = map ?? OfficeArt.color(hex)
        if let scale {
            m.diffuse.wrapS = .repeat; m.diffuse.wrapT = .repeat
            m.diffuse.contentsTransform = SCNMatrix4MakeScale(scale.0, scale.1, 1)
        }
        m.diffuse.mipFilter = .linear
        m.roughness.contents = rough
        m.metalness.contents = metal
        m.isDoubleSided = double
        return m
    }

    /// O'zi nur sochadigan (yorug'likka bog'liq emas) — ko'krak chirog'i, antenna, ekran
    static func glow(_ hex: Int, dim: Bool = false) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = OfficeArt.color(hex)
        m.diffuse.intensity = dim ? 0.35 : 1.6
        return m
    }

    /// Doim ko'rinadigan rasm (belgi, yorliq) — boshqa narsalar ortida qolmaydi
    static func overlay(_ image: Any?, additive: Bool = false) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = image
        m.isDoubleSided = true
        m.readsFromDepthBuffer = false
        m.writesToDepthBuffer = false
        m.blendMode = additive ? .add : .alpha
        return m
    }

    static let plaster = std(0xECE6DC, rough: 0.95)
    static let wallCap = std(0x34333A, rough: 0.7)
    static let oak = std(0xB48B62, rough: 0.5)
    static let walnut = std(0x6B4A33, rough: 0.55)
    static let metal = std(0x2B2B31, rough: 0.4, metal: 0.6)
    static let blackPlastic = std(0x141418, rough: 0.35)
    static let terracotta = std(0xB06A4D, rough: 0.9)
    static let ceramic = std(0xF1ECE4, rough: 0.3)
    static let keyboard = std(0x2C2B33, rough: 0.5)
    static let chair = std(0x2F2E36, rough: 0.75)
    static let soil = std(0x3A2A20)
    static let bark = std(0x5B4332)
    static let leaves = [0x4F7D4F, 0x5F9160, 0x3F6A45, 0x6FA36A].map { std($0, rough: 0.6, double: true) }
    static let crowns = [0x3F6A3F, 0x4C7A45, 0x5A8A4E, 0x47733F].map { std($0, rough: 0.9) }
    static let sofas = [0x7D8F7A, 0xB5735A, 0x6C7F99, 0xC49A4A, 0x9A7F9E, 0x8A9A6C]
    static let books = [0xC44F3D, 0x2F5D8A, 0xD9B25A, 0x3D7A5A, 0xE8E2D8, 0x6A4A8A].map { std($0, rough: 0.7) }
    static let robotWhite: SCNMaterial = {
        let m = std(0xF3F2F9, rough: 0.32)
        m.clearCoat.contents = 1; m.clearCoatRoughness.contents = 0.18
        return m
    }()
    static let robotJoint = std(0xB9B5CC, rough: 0.5)
    static let visor: SCNMaterial = {
        let m = std(0x0A0A10, rough: 0.12); m.clearCoat.contents = 1; return m
    }()
    static let graphite: SCNMaterial = {
        let m = std(0x34353E, rough: 0.35); m.clearCoat.contents = 1; m.clearCoatRoughness.contents = 0.25; return m
    }()
    static let glass: SCNMaterial = {
        let m = std(0xCFE4EE, rough: 0.05)
        m.transparency = 0.16
        m.writesToDepthBuffer = false
        m.blendMode = .alpha
        return m
    }()
    static let woodFloor = std(0xFFFFFF, rough: 0.55, map: OfficeArt.woodFloor(), scale: (1.6, 1.6))
    static let concrete = std(0xFFFFFF, rough: 0.92, map: OfficeArt.concrete(), scale: (8, 5))
    static let grass = std(0xFFFFFF, rough: 1, map: OfficeArt.grass(), scale: (30, 30))
    static let lawn = std(0xFFFFFF, rough: 1, map: OfficeArt.grass(), scale: (1, 1))
    static let path = std(0xB9B2A6, rough: 0.95)
}

@discardableResult
func addNode(_ parent: SCNNode, _ geo: SCNGeometry, _ mat: SCNMaterial, _ x: CGFloat = 0, _ y: CGFloat = 0, _ z: CGFloat = 0,
             cast: Bool = true) -> SCNNode {
    let n = SCNNode(geometry: geo)
    geo.firstMaterial = mat
    n.position = SCNVector3(x, y, z)
    n.castsShadow = cast
    parent.addChildNode(n)
    return n
}

func omni(_ hex: Int, range: CGFloat) -> SCNLight {
    let l = SCNLight()
    l.type = .omni
    l.color = OfficeArt.color(hex)
    l.intensity = 0
    l.attenuationStartDistance = 0
    l.attenuationEndDistance = range
    l.attenuationFalloffExponent = 2
    return l
}

/// Stol: ustida monitor (holatga qarab ekran), klaviatura, krujka; oldida stul
final class Desk {
    let screen: SCNMaterial
    let light: SCNNode
    /// Robot o'tiradigan joy
    let seat: SCNVector3
    var shown: String = ""

    init(_ g: SCNNode, x: CGFloat, z: CGFloat) {
        addNode(g, Geo.rbox(1.4, 0.04, 0.7, 0.015), Mat.oak, x, 0.74, z)
        for dx in [-0.64, 0.64] as [CGFloat] { addNode(g, Geo.box(0.04, 0.72, 0.6), Mat.metal, x + dx, 0.36, z) }
        addNode(g, Geo.box(1.24, 0.03, 0.03), Mat.metal, x, 0.62, z - 0.25)
        addNode(g, Geo.cyl(0.1, 0.11, 0.015), Mat.metal, x, 0.768, z - 0.2)
        addNode(g, Geo.box(0.04, 0.2, 0.025), Mat.metal, x, 0.87, z - 0.22)
        addNode(g, Geo.rbox(0.66, 0.4, 0.03, 0.012), Mat.blackPlastic, x, 1.04, z - 0.21)
        screen = SCNMaterial()
        screen.lightingModel = .constant
        screen.diffuse.contents = OfficeArt.screen(nil, tool: nil)
        addNode(g, Geo.plane(0.62, 0.36), screen, x, 1.04, z - 0.193, cast: false)
        addNode(g, Geo.rbox(0.42, 0.015, 0.14, 0.006), Mat.keyboard, x - 0.05, 0.768, z + 0.12)
        addNode(g, Geo.rbox(0.07, 0.015, 0.1, 0.006), Mat.keyboard, x + 0.28, 0.768, z + 0.12)
        addNode(g, Geo.cyl(0.04, 0.035, 0.1, seg: 16), Mat.ceramic, x - 0.5, 0.81, z + 0.05)
        // stul
        let cz = z + 0.62
        addNode(g, Geo.cyl(0.26, 0.26, 0.03, seg: 20), Mat.metal, x, 0.03, cz)
        addNode(g, Geo.cyl(0.03, 0.03, 0.34, seg: 10), Mat.metal, x, 0.22, cz)
        addNode(g, Geo.rbox(0.48, 0.07, 0.46, 0.03), Mat.chair, x, 0.43, cz)
        addNode(g, Geo.rbox(0.46, 0.34, 0.06, 0.03), Mat.chair, x, 0.68, cz + 0.24)
        light = SCNNode(); light.light = omni(0x9FD8FF, range: 2.6); light.position = SCNVector3(x, 1.0, z + 0.05)
        g.addChildNode(light)
        seat = SCNVector3(x, 0.5, cz)
    }

    func show(_ state: OfficeState?, tool: OfficeTool?, night: Bool) {
        let key = "\(state.map { "\($0.rawValue)" } ?? "-")\(String(describing: tool))"
        if key != shown {
            shown = key
            screen.diffuse.contents = OfficeArt.screen(state, tool: tool)
        }
        if let state, let look = OfficeArt.screenLook(state) {
            light.light?.color = OfficeArt.color(look.light)
            light.light?.intensity = (state == .working ? 22 : 14) * (night ? 1.4 : 1)
        } else {
            light.light?.intensity = 0
        }
    }
}

/// Bitta xona: devorlar, ikki stol, dam olish burchagi (gilam, divan, stolcha), javon, gullar, torshyer
final class Room {
    let id: String
    let slot: Int
    let node = SCNNode()
    let floor: SCNNode
    let desks: [Desk]
    let light: SCNNode
    let lamp: SCNNode
    let shade: SCNMaterial
    let outline = SCNNode()
    let ring: SCNMaterial
    let label = SCNNode()
    var labelKey = ""
    var data: OfficeRoom
    var bots: [String: Bot] = [:]
    var center: SCNVector3 { SCNVector3(Office.slots[slot].0, 0, Office.slots[slot].1) }

    init(_ r: OfficeRoom, slot i: Int) {
        id = r.id; slot = i; data = r
        let g = node
        g.name = "room:" + r.id
        g.position = SCNVector3(Office.slots[i].0, 0.1, Office.slots[i].1)
        floor = addNode(g, Geo.plane(6, 5), Mat.woodFloor, 0, 0.003, 0, cast: false)
        floor.eulerAngles.x = -.pi / 2
        floor.name = "room:" + r.id
        func wall(_ w: CGFloat, _ d: CGFloat, _ x: CGFloat, _ z: CGFloat, _ h: CGFloat = 1.1) {
            addNode(g, Geo.box(w, h, d), Mat.plaster, x, h / 2, z)
            addNode(g, Geo.box(w + 0.002, 0.02, d + 0.002), Mat.wallCap, x, h + 0.01, z, cast: false)
        }
        wall(6.12, 0.12, 0, -2.5); wall(0.12, 5, -3, 0); wall(0.12, 5, 3, 0)
        // old tomoni — shisha, eshik bilan
        for (x, w) in [(-1.25, 3.5), (2.3, 1.4)] as [(CGFloat, CGFloat)] {
            addNode(g, Geo.box(w, 1.0, 0.03), Mat.glass, x, 0.5, 2.5, cast: false)
            addNode(g, Geo.box(w, 0.03, 0.05), Mat.metal, x, 1.0, 2.5, cast: false)
        }
        desks = [-1.75, 0.05].map { Desk(g, x: $0, z: -1.85) }
        // dam olish burchagi
        let rug = addNode(g, Geo.plane(2.3, 2.5), Mat.std(0xFFFFFF, rough: 1, map: OfficeArt.rug(i)), 1.75, 0.006, 1.0, cast: false)
        rug.eulerAngles.x = -.pi / 2
        let fabric = Mat.std(Mat.sofas[i % Mat.sofas.count], rough: 0.95)
        let sz: CGFloat = 1.0
        addNode(g, Geo.rbox(0.85, 0.4, 2.0, 0.06), fabric, 2.5, 0.22, sz)
        addNode(g, Geo.rbox(0.2, 0.44, 2.0, 0.06), fabric, 2.82, 0.62, sz)
        for dz in [-1.08, 1.08] as [CGFloat] { addNode(g, Geo.rbox(0.85, 0.6, 0.16, 0.06), fabric, 2.5, 0.32, sz + dz) }
        for dz in [-0.49, 0.49] as [CGFloat] {
            addNode(g, Geo.rbox(0.62, 0.13, 0.95, 0.06), fabric, 2.42, 0.47, sz + dz)
            addNode(g, Geo.rbox(0.16, 0.4, 0.92, 0.07), fabric, 2.66, 0.72, sz + dz).eulerAngles.z = 0.15
        }
        addNode(g, Geo.cyl(0.38, 0.38, 0.035, seg: 32), Mat.walnut, 1.3, 0.42, sz)
        addNode(g, Geo.cyl(0.04, 0.05, 0.4, seg: 10), Mat.metal, 1.3, 0.2, sz)
        addNode(g, Geo.cyl(0.2, 0.2, 0.02, seg: 20), Mat.metal, 1.3, 0.01, sz)
        addNode(g, Geo.rbox(0.24, 0.035, 0.17, 0.008), Mat.std(0x8B3A3A), 1.22, 0.455, sz - 0.12).eulerAngles.y = 0.3
        addNode(g, Geo.cyl(0.04, 0.035, 0.1, seg: 16), Mat.ceramic, 1.42, 0.49, sz + 0.14)
        // javon va kitoblar
        addNode(g, Geo.rbox(1.5, 0.85, 0.3, 0.02), Mat.walnut, 1.75, 0.425, -2.28)
        for k in 0..<6 {
            addNode(g, Geo.box(0.05 + CGFloat(k % 2) * 0.02, 0.24 + CGFloat(k % 3) * 0.04, 0.2), Mat.books[k],
                    1.15 + CGFloat(k) * 0.08, 0.97 + CGFloat(k % 3) * 0.02, -2.28)
        }
        var rnd = OfficeArt.Rand(seed: 21 + i)
        Office.plant(g, 2.35, -2.25, 0.55, &rnd)
        Office.plant(g, 2.55, -1.55, 0.9, &rnd)
        Office.plant(g, -2.55, 2.05, 1.0, &rnd)
        // torshyer
        addNode(g, Geo.cyl(0.16, 0.16, 0.02, seg: 20), Mat.metal, 2.6, 0.01, 2.2)
        addNode(g, Geo.cyl(0.015, 0.015, 1.45, seg: 8), Mat.metal, 2.6, 0.73, 2.2)
        shade = Mat.std(0xF1E6D2, rough: 0.9, double: true)
        shade.emission.contents = OfficeArt.color(0xFFC98A)
        shade.emission.intensity = 0
        let shadeGeo = SCNTube(innerRadius: 0.16, outerRadius: 0.165, height: 0.24); shadeGeo.radialSegmentCount = 24
        addNode(g, shadeGeo, shade, 2.6, 1.5, 2.2, cast: false)
        lamp = SCNNode(); lamp.light = omni(0xFFC98A, range: 4); lamp.position = SCNVector3(2.6, 1.35, 2.2); g.addChildNode(lamp)
        // xona chirog'i
        light = SCNNode(); light.light = omni(0xFFD9B0, range: 9); light.light?.attenuationFalloffExponent = 1
        light.position = SCNVector3(-0.2, 3.2, 0); g.addChildNode(light)
        // ruxsat kutilsa — sariq chegara
        ring = Mat.glow(OfficeArt.warn)
        ring.diffuse.intensity = 1.4
        outline.isHidden = true
        g.addChildNode(outline)
        for (w, d, x, z) in [(5.76, 0.05, 0, -2.4), (5.76, 0.05, 0, 2.4), (0.05, 4.8, -2.9, 0), (0.05, 4.8, 2.9, 0)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
            addNode(outline, Geo.box(w, 0.012, d), ring, x, 0.012, z, cast: false)
        }
        // yorliq: xona ustida, kameraga qaragan
        label.position = SCNVector3(-0.4, 1.6, 0.7)
        label.constraints = [SCNBillboardConstraint()]
        label.renderingOrder = 100
        g.addChildNode(label)
    }

    /// Yorliq rasmi faqat matn o'zgarganda qayta chiziladi
    func updateLabel() {
        let st = data.state
        let tint = st == .waiting ? OfficeArt.warn : st == .error ? OfficeArt.err : st.busy ? OfficeArt.ok : 0xB8B8C2
        let key = "\(data.id)|\(data.status)|\(tint)"
        guard key != labelKey else { return }
        labelKey = key
        let img = OfficeArt.label(title: data.id, status: data.status, tint: tint, alert: st == .waiting)
        let h: CGFloat = 0.3, w = h * CGFloat(img.width) / CGFloat(img.height)
        let plane = SCNPlane(width: w, height: h)
        plane.firstMaterial = Mat.overlay(img)
        label.geometry = plane
        label.name = "label:" + data.id
    }
}

/// Bino, tashqari, yorug'lik va bo'sh joylardagi bog'chalar
enum Office {
    /// Xona markazlari: tepada 3 ta, pastda 3 ta
    static let slots: [(CGFloat, CGFloat)] = [(-7, -3), (0, -3), (7, -3), (-7, 3), (0, 3), (7, 3)]

    static func plant(_ parent: SCNNode, _ x: CGFloat, _ z: CGFloat, _ s: CGFloat, _ rnd: inout OfficeArt.Rand) {
        let p = SCNNode(); p.position = SCNVector3(x, 0, z); p.scale = SCNVector3(s, s, s); parent.addChildNode(p)
        addNode(p, Geo.cyl(0.22, 0.17, 0.42), Mat.terracotta, 0, 0.21, 0)
        addNode(p, Geo.cyl(0.2, 0.2, 0.02), Mat.soil, 0, 0.41, 0, cast: false)
        for i in 0..<11 {
            let ang = CGFloat(i) / 11 * .pi * 2 + rnd.next() * 0.4, tilt = 0.5 + rnd.next() * 0.7, len = 0.45 + rnd.next() * 0.3
            let stem = SCNNode(); stem.position = SCNVector3(0, 0.42, 0); stem.eulerAngles.y = ang; p.addChildNode(stem)
            let leaf = addNode(stem, Geo.sphere(0.17, seg: 12), Mat.leaves[i % 4], 0, cos(tilt) * len, sin(tilt) * len * 0.8)
            leaf.scale = SCNVector3(0.75, 0.12, 1.25); leaf.eulerAngles.x = tilt - 0.3
        }
    }

    static func tree(_ parent: SCNNode, _ x: CGFloat, _ z: CGFloat, _ s: CGFloat) {
        let t = SCNNode(); t.position = SCNVector3(x, 0, z); t.scale = SCNVector3(s, s, s); parent.addChildNode(t)
        addNode(t, Geo.cyl(0.1, 0.16, 1.5, seg: 10), Mat.bark, 0, 0.75, 0)
        for (i, c) in [(0, 1.9, 0, 1.0), (0.45, 1.6, 0.2, 0.75), (-0.4, 1.7, -0.15, 0.8), (0.1, 2.4, -0.1, 0.7)].enumerated() as EnumeratedSequence<[(CGFloat, CGFloat, CGFloat, CGFloat)]> {
            let n = addNode(t, Geo.sphere(c.3, seg: 10), Mat.crowns[i], c.0, c.1, c.2)
            n.geometry?.firstMaterial = Mat.crowns[i]
        }
    }

    /// Bo'sh xona joyi — maysa, gullar, daraxt va ikki o'rindiq
    static func garden(_ slot: Int) -> SCNNode {
        let g = SCNNode(); g.position = SCNVector3(slots[slot].0, 0.1, slots[slot].1)
        addNode(g, Geo.plane(5.4, 4.4), Mat.lawn, 0, 0.004, 0, cast: false).eulerAngles.x = -.pi / 2
        var rnd = OfficeArt.Rand(seed: 40 + slot)
        for (k, p) in [(-1.8, -1.3), (1.6, 1.2), (1.9, -1.5)].enumerated() as EnumeratedSequence<[(CGFloat, CGFloat)]> {
            plant(g, p.0, p.1, 0.8 + CGFloat(k) * 0.15, &rnd)
        }
        tree(g, -0.2, -0.2, 1)
        for s in [-1, 1] as [CGFloat] {
            addNode(g, Geo.rbox(1.4, 0.06, 0.4, 0.02), Mat.oak, s * 1.6, 0.45, 0.2 * s)
            addNode(g, Geo.box(1.2, 0.42, 0.06), Mat.metal, s * 1.6, 0.21, 0.2 * s)
        }
        return g
    }

    /// Yer, bino poli, tashqi devorlar, oldidagi shisha va yo'lka, atrofdagi daraxtlar
    static func building(_ root: SCNNode) {
        let ground = addNode(root, Geo.plane(160, 160), Mat.grass, 0, 0, 0, cast: false); ground.eulerAngles.x = -.pi / 2
        addNode(root, Geo.box(21.4, 0.1, 12.4), Mat.concrete, 0, 0.05, 0, cast: false)
        addNode(root, Geo.plane(2.2, 12), Mat.path, 0, 0.012, 12.2, cast: false).eulerAngles.x = -.pi / 2
        for (w, d, x, z) in [(21.4, 0.2, 0, -6.2), (0.2, 12.4, -10.7, 0), (0.2, 12.4, 10.7, 0)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
            addNode(root, Geo.box(w, 1.1, d), Mat.plaster, x, 0.65, z)
            addNode(root, Geo.box(w + 0.002, 0.02, d + 0.002), Mat.wallCap, x, 1.21, z, cast: false)
        }
        for (x, w) in [(-5.95, 9.5), (5.95, 9.5)] as [(CGFloat, CGFloat)] {
            addNode(root, Geo.box(w, 1.0, 0.04), Mat.glass, x, 0.6, 6.2, cast: false)
            addNode(root, Geo.box(w, 0.04, 0.08), Mat.metal, x, 1.1, 6.2, cast: false)
        }
        var rnd = OfficeArt.Rand(seed: 11)
        for _ in 0..<34 {
            let ang = rnd.next() * .pi * 2, rad = 15 + rnd.next() * 14
            let x = cos(ang) * rad * 1.25, z = sin(ang) * rad * 0.9
            let s = 0.9 + rnd.next() * 0.8
            if abs(x) < 2.5 && z > 6 { continue }
            tree(root, x, z, s)
        }
    }

    /// Kun vaqti: osmon, quyosh yo'nalishi va rangi
    struct Sky { let sky: Int, ground: Int, ambient: CGFloat, sun: Int, sunI: CGFloat, pos: SCNVector3, bg: Int, env: CGFloat, exposure: CGFloat, night: Bool }

    static func sky(at date: Date) -> Sky {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        let h = Double(c.hour ?? 12) + Double(c.minute ?? 0) / 60
        switch h {
        case 7..<17: return Sky(sky: 0xDFE9FF, ground: 0x5B4A3A, ambient: 260, sun: 0xFFF1DE, sunI: 2100, pos: SCNVector3(-12, 22, -6), bg: 0xB9CBD9, env: 1.1, exposure: 0, night: false)
        case 17..<19.5: return Sky(sky: 0x8A86C9, ground: 0x3A2A20, ambient: 160, sun: 0xFFA168, sunI: 1500, pos: SCNVector3(-22, 9, -4), bg: 0x3B3456, env: 0.6, exposure: 0.1, night: false)
        case 5..<7: return Sky(sky: 0x9AA0D9, ground: 0x3A2E28, ambient: 160, sun: 0xFFB98A, sunI: 1300, pos: SCNVector3(22, 9, -4), bg: 0x4A4466, env: 0.6, exposure: 0.1, night: false)
        default: return Sky(sky: 0x22305E, ground: 0x0C0D14, ambient: 110, sun: 0x8FA6FF, sunI: 320, pos: SCNVector3(-10, 20, -10), bg: 0x0B0E1A, env: 0.3, exposure: 0.25, night: true)
        }
    }
}
