import Foundation

/// GitHub'dagi so'nggi reliz: yangi versiya bormi va DMG qayerdan yuklanadi.
/// Faqat ochiq reliz ma'lumoti o'qiladi — hech qanday foydalanuvchi ma'lumoti yuborilmaydi.
public struct ReleaseInfo: Equatable, Sendable {
    public let version: String
    public let pageURL: URL
    /// DMG fayli (bo'lmasa — reliz sahifasi)
    public let downloadURL: URL
    /// DMG yonidagi `.sha256` fayli — ilova ichida yangilashda yuklangan DMG shu bilan tekshiriladi
    public let checksumURL: URL?
    public let notes: String

    public static let apiURL = URL(string: "https://api.github.com/repos/aliumirovux/TokenKuzat/releases/latest")!

    /// GitHub API javobi → reliz (qoralama yoki «pre-release» — nil)
    public static func parse(_ data: Data) -> ReleaseInfo? {
        guard let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let tag = o["tag_name"] as? String, let page = (o["html_url"] as? String).flatMap(URL.init(string:)),
              (o["draft"] as? Bool) != true, (o["prerelease"] as? Bool) != true else { return nil }
        let assets = o["assets"] as? [[String: Any]] ?? []
        func asset(_ suffix: String) -> URL? {
            assets.compactMap { a -> URL? in
                guard let name = a["name"] as? String, name.lowercased().hasSuffix(suffix) else { return nil }
                return (a["browser_download_url"] as? String).flatMap(URL.init(string:))
            }.first
        }
        let dmg = asset(".dmg")
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        return ReleaseInfo(version: version, pageURL: page, downloadURL: dmg ?? page,
                           checksumURL: dmg == nil ? nil : asset(".dmg.sha256"), notes: o["body"] as? String ?? "")
    }

    /// Ilova ichida o'rnatish mumkinmi: DMG ham, uning SHA-256 fayli ham bor
    public var canInstall: Bool { downloadURL.pathExtension.lowercased() == "dmg" && checksumURL != nil }

    /// `shasum -a 256` chiqishi («<64 hex>  fayl») → kichik harfli hex
    public static func parseChecksum(_ text: String) -> String? {
        guard let first = text.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).first else { return nil }
        let hex = first.lowercased()
        return hex.count == 64 && hex.allSatisfy(\.isHexDigit) ? hex : nil
    }
}

public enum AppVersion {
    /// «6.27.0» > «6.26.1»; raqam bo'lmagan qismlar (masalan, «dev») — 0
    public static func isNewer(_ a: String, than b: String) -> Bool {
        func parts(_ s: String) -> [Int] { s.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 } }
        let x = parts(a), y = parts(b)
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}
