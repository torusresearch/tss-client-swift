// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "tss-client-swift",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "tss-client-swift",
            targets: ["tss-client-swift"]),
    ],
    dependencies: [
        .package(name: "BigInt", url: "https://github.com/attaswift/BigInt.git", from: "5.3.0"),
        .package(name: "CryptoSwift", url: "https://github.com/krzyzanowskim/CryptoSwift.git",from: "1.7.2"),
        .package(name: "secp256k1", url: "https://github.com/GigaBitcoin/secp256k1.swift", .upToNextMajor(from: "0.12.2")),
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
            dependencies: ["BigInt", "CryptoSwift", "secp256k1", "SocketIO", "dkls"]),
        .testTarget(
            name: "tss-client-swiftTests",
            dependencies: ["tss-client-swift", "BigInt"]),
    ]
)
