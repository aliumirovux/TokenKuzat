import Foundation
#if canImport(CoreServices)
import CoreServices
#endif

/// Kuzatilayotgan papkalardagi o'zgargan fayllar (macOS FSEvents). Engine shu ro'yxat bilan har soniyada
/// minglab faylni tekshirmaydi: faqat o'zgarganini o'qiydi, papkalarni esa yangi fayl paydo bo'lganda aylanadi.
/// O'zgarishlar tizim navbatida yig'iladi, Engine ularni `drain()` bilan oladi.
final class ChangeWatcher {
    struct Changes {
        var paths: Set<String> = []
        /// Tizim voqealarni tashlab yuborgan yoki papka ko'chgan — hammasini qaytadan ko'rish kerak
        var rescan = false
    }

    /// Kuzatilayotgan papkalar (Engine ko'radigan ko'rinishda)
    let roots: [String]
    private let lock = NSLock()
    private var pending = Changes()
    /// FSEvents yo'lni symlink'larsiz beradi — Engine'dagi yo'lga qaytarish uchun: (haqiqiy prefiks, Engine prefiksi)
    private let aliases: [(real: String, shown: String)]
    private let queue = DispatchQueue(label: "uz.ali.tokenkuzat.watcher", qos: .utility)
    #if canImport(CoreServices)
    private var stream: FSEventStreamRef?
    #endif

    /// `start: false` — oqimsiz (testlar uchun): o'zgarishlar `record` bilan beriladi
    init(roots: [URL], start: Bool = true) {
        self.roots = roots.map(\.path)
        aliases = roots.compactMap { r in
            let real = r.resolvingSymlinksInPath().path
            return real == r.path ? nil : (real, r.path)
        }
        if start { self.start() }
    }

    /// Kuzatuv ishga tushmasa (FSEvents yo'q yoki xato) — nil: Engine avvalgidek hamma fayllarni tekshiradi
    static func make(roots: [URL]) -> ChangeWatcher? {
        #if canImport(CoreServices)
        let w = ChangeWatcher(roots: roots)
        return w.stream == nil ? nil : w
        #else
        return nil
        #endif
    }

    func record(_ paths: [String], rescan: Bool = false) {
        lock.lock()
        defer { lock.unlock() }
        for p in paths { pending.paths.insert(shown(p)) }
        if rescan { pending.rescan = true }
    }

    func drain() -> Changes {
        lock.lock()
        defer { lock.unlock() }
        let c = pending
        pending = Changes()
        return c
    }

    private func shown(_ path: String) -> String {
        for a in aliases where path.hasPrefix(a.real + "/") { return a.shown + path.dropFirst(a.real.count) }
        return path
    }

    #if canImport(CoreServices)
    private func start() {
        guard !roots.isEmpty else { return }
        var ctx = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                       retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, count, paths, flags, _ in
            guard let info else { return }
            let watcher = Unmanaged<ChangeWatcher>.fromOpaque(info).takeUnretainedValue()
            let list = Unmanaged<NSArray>.fromOpaque(paths).takeUnretainedValue() as? [String] ?? []
            let lost = FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs | kFSEventStreamEventFlagUserDropped
                                               | kFSEventStreamEventFlagKernelDropped | kFSEventStreamEventFlagRootChanged)
            let rescan = (0..<count).contains { flags[$0] & lost != 0 }
            watcher.record(list, rescan: rescan)
        }
        let opts = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer
                                            | kFSEventStreamCreateFlagUseCFTypes)
        // Voqealar 1 soniya yig'ilib keladi — tez yozilayotgan transkript har qatorda uyg'otmaydi
        guard let s = FSEventStreamCreate(kCFAllocatorDefault, callback, &ctx, roots as CFArray,
                                          FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 1.0, opts) else { return }
        FSEventStreamSetDispatchQueue(s, queue)
        guard FSEventStreamStart(s) else {
            FSEventStreamInvalidate(s)
            FSEventStreamRelease(s)
            return
        }
        stream = s
    }

    deinit {
        guard let s = stream else { return }
        FSEventStreamStop(s)
        FSEventStreamInvalidate(s)
        // Navbatda boshlangan chaqiruv tugashini kutadi — u `self` ga murojaat qiladi
        queue.sync {}
        FSEventStreamRelease(s)
    }
    #else
    private func start() {}
    #endif
}
