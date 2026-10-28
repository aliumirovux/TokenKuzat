import SwiftUI
import AppKit
import Quartz
import QuickLookThumbnailing
import TokenKuzatCore

/// «Natijalar» tabi: sessiyada yaratilgan yoki ko'rilgan rasm, HTML, PDF va videolar — chapda ro'yxat, o'ngda katta ko'rinish
struct OutputsScreen: View {
    let session: SessionSnap
    @State private var selected: String?
    @State private var filter: OutputFile.Kind?

    var body: some View {
        let all = SessionOutputs.collect(session)
        let files = filter.map { k in all.filter { $0.kind == k } } ?? all
        let current = files.first { $0.path == selected } ?? files.first
        if all.isEmpty {
            EmptyStateView(symbol: "photo.on.rectangle.angled",
                           title: "Hozircha natija yo'q",
                           text: "Claude bu sessiyada rasm, HTML, PDF yoki video yaratsa yoki ochsa — shu yerda ko'rinadi.")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    filters(all)
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(files) { f in
                                OutputTile(file: f, selected: f.path == current?.path)
                                    .onTapGesture { selected = f.path }
                            }
                        }
                        .padding(.bottom, 12)
                    }
                }
                .padding([.top, .horizontal], 12)
                .frame(width: 300)
                Divider()
                if let current {
                    OutputDetail(file: current)
                } else {
                    Spacer()
                }
            }
        }
    }

    private func filters(_ all: [OutputFile]) -> some View {
        let kinds = [OutputFile.Kind.image, .web, .pdf, .video].filter { k in all.contains { $0.kind == k } }
        return HStack(spacing: 6) {
            chip(nil, "Hammasi · \(all.count)")
            ForEach(kinds, id: \.self) { k in chip(k, "\(k.title) · \(all.filter { $0.kind == k }.count)") }
        }
    }

    private func chip(_ k: OutputFile.Kind?, _ title: String) -> some View {
        let on = filter == k
        return Button { withAnimation(Motion.snappy) { filter = k } } label: {
            Text(title)
                .font(.caption.weight(on ? .semibold : .regular))
                .foregroundStyle(on ? .primary : .secondary)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(Capsule().fill(on ? Brand.surface : .clear))
                .overlay(Capsule().stroke(on ? Brand.line : .clear))
        }
        .buttonStyle(.plain)
    }
}

/// Ro'yxatdagi bitta fayl: kichik rasm, nomi, turi va qachon
private struct OutputTile: View {
    let file: OutputFile
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Thumbnail(path: file.path)
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            HStack(spacing: 6) {
                Text(file.kind.title).font(.caption2.weight(.bold)).foregroundStyle(Brand.accent)
                Text(file.name).font(.caption.weight(.semibold)).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 0)
            }
            HStack(spacing: 6) {
                Text(file.written ? "Yaratildi" : "Ko'rildi")
                if let d = file.lastActivity { Text("· " + d.formatted(date: .omitted, time: .shortened)) }
            }
            .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(selected ? Brand.surface : .clear))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(selected ? Brand.accent : Brand.line))
        .contentShape(Rectangle())
    }
}

/// Katta ko'rinish: Quick Look (rasm, HTML, PDF, video) va ochish tugmalari
private struct OutputDetail: View {
    let file: OutputFile

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name).font(.callout.weight(.semibold)).lineLimit(1).truncationMode(.middle)
                    Text(file.folder).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.head)
                }
                Spacer()
                Button {
                    NSWorkspace.shared.open(URL(fileURLWithPath: file.path))
                } label: { Label(file.kind == .web ? "Brauzerda ochish" : "Ochish", systemImage: "arrow.up.forward.app") }
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file.path)])
                } label: { Label("Finder", systemImage: "folder") }
            }
            .padding(12)
            Divider()
            QuickLookView(url: URL(fileURLWithPath: file.path))
                .id(file.path)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Quick Look ko'rinishi: fayl o'zgarsa (Claude qayta yozsa) — yangilanadi
private struct QuickLookView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let v = QLPreviewView(frame: .zero, style: .normal)!
        v.autostarts = true
        v.previewItem = url as NSURL
        context.coordinator.watch(url, view: v)
        return v
    }

    func updateNSView(_ v: QLPreviewView, context: Context) {
        if (v.previewItem as? NSURL) as URL? != url {
            v.previewItem = url as NSURL
            context.coordinator.watch(url, view: v)
        }
    }

    static func dismantleNSView(_ v: QLPreviewView, coordinator: Coordinator) {
        coordinator.timer?.invalidate()
        v.close()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var timer: Timer?
        private var mtime: Date?

        func watch(_ url: URL, view: QLPreviewView) {
            timer?.invalidate()
            mtime = Self.modified(url)
            timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self, weak view] _ in
                guard let self, let view else { return }
                let m = Self.modified(url)
                if m != self.mtime { self.mtime = m; view.refreshPreviewItem() }
            }
        }

        static func modified(_ url: URL) -> Date? {
            (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
        }
    }
}

/// Kichik rasm: Quick Look thumbnail (rasm, HTML, PDF, video uchun bir xil); fayl o'zgarsa qayta olinadi
private struct Thumbnail: View {
    let path: String
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "photo").font(.title2).foregroundStyle(.tertiary)
            }
        }
        .task(id: key) { image = await Self.load(path) }
    }

    private var key: String {
        let m = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
        return path + "|\(m?.timeIntervalSince1970 ?? 0)"
    }

    static func load(_ path: String) async -> NSImage? {
        let req = QLThumbnailGenerator.Request(fileAt: URL(fileURLWithPath: path), size: CGSize(width: 560, height: 300),
                                               scale: 2, representationTypes: .thumbnail)
        return await withCheckedContinuation { c in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: req) { rep, _ in
                c.resume(returning: rep?.nsImage)
            }
        }
    }
}
