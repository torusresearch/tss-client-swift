// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "tss-client-swift",
    platforms: [.iOS(.v13), .macOS(.v10_15)],
    products: [
        .library(
            name: "tss-client-swift",
            targets: ["tss-client-swift"]),
    ],
    dependencies: [
        .package(name: "BigInt", url: "https://github.com/attaswift/BigInt.git", from: "5.3.0"),
        .package(name: "CryptoSwift", url: "https://github.com/krzyzanowskim/CryptoSwift.git",from: "1.7.2"),
        .package(name: "curvelib.swift", url: "https://github.com/tkey/curvelib.swift", .branch("refactor")),
        .package(name: "SocketIO", url: "https://github.com/socketio/socket.io-client-swift", .upToNextMajor(from: "16.0.1")),
    ],
    targets: [
        .binaryTarget(name: "libdkls",
                      path: "Sources/libdkls/libdkls.xcframework"
        ),
        .target(name: "dkls",
               dependencies: ["libdkls"],
                path: "Sources/libdkls"
        ),
        .target(
            name: "tss-client-swift",
            dependencies: ["BigInt", "CryptoSwift", "curvelib.swift", "SocketIO", "dkls"]),
        .testTarget(
            name: "tss-client-swiftTests",
            dependencies: ["tss-client-swift", "BigInt"]),
    ]
)
