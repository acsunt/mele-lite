// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MeleLite",
    defaultLocalization: "zh-Hans",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "MeleLiteCore", targets: ["MeleLiteCore"]),
    ],
    targets: [
        .target(name: "MeleLiteCore", resources: [.copy("Prompts")]),
        .testTarget(name: "MeleLiteCoreTests", dependencies: ["MeleLiteCore"], resources: [.copy("Fixtures")]),
    ]
)
