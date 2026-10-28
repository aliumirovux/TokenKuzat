// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TokenKuzat",
    platforms: [.macOS(.v13)],
    targets: [
        // Transcript o'qish, hisoblash va tarix — UI'siz, test qilinadigan qism
        .target(name: "TokenKuzatCore", path: "Sources/TokenKuzatCore"),
        .executableTarget(name: "TokenKuzat", dependencies: ["TokenKuzatCore"], path: "Sources/TokenKuzat"),
        .testTarget(name: "TokenKuzatCoreTests", dependencies: ["TokenKuzatCore"], path: "Tests/TokenKuzatCoreTests"),
    ]
)
