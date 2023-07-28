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
        .package(name: "CryptoSwift", url: "https://github.com/krzyzanowskim/CryptoSwift.git",from: "1.5.1"),
        .package(name: "secp256k1", url: "https://github.com/Boilertalk/secp256k1.swift", from: "0.1.0"),
        .package(name: "SwiftKeccak", url: "https://github.com/bitflying/SwiftKeccak.git", from: "0.1.0"),
        .package(name: "SocketIO", url: "https://github.com/socketio/socket.io-client-swift", .upToNextMajor(from: "16.0.1"))
    ],
    targets: [
        .binaryTarget(name: "libdklsnative",
                      path: "Sources/libdkls/libdkls.xcframework"
        ),
        .target(name: "libdkls",
               dependencies: ["libdklsnative"],
                path: "Sources/libdkls"
        ),
        .target(
            name: "tss-client-swift",
            dependencies: ["BigInt", "CryptoSwift", "secp256k1", "SwiftKeccak", "SocketIO", "libdkls"]),
        .testTarget(
            name: "tss-client-swiftTests",
            dependencies: ["tss-client-swift", "BigInt"]),
    ]
)
