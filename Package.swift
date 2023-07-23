// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "tss-client-swift",
    platforms: [.iOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "tss-client-swift",
            targets: ["tss-client-swift"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(name: "BigInt", url: "https://github.com/attaswift/BigInt.git", from: "5.3.0"),
        .package(name: "CryptoSwift", url: "https://github.com/krzyzanowskim/CryptoSwift.git",from: "1.5.1"),
        .package(name: "secp256k1", url: "https://github.com/Boilertalk/secp256k1.swift", from: "0.1.0"),
        .package(name: "SwiftKeccak", url: "https://github.com/bitflying/SwiftKeccak.git", from: "0.1.0"),
        //.package(name: "SocketIO", url: "https://github.com/socketio/socket.io-client-swift", //.upToNextMajor(from: "16.0.1"))
        .package(name: "SocketIO", url: "https://github.com/socketio/socket.io-client-swift", .upToNextMajor(from: "16.0.1"))
    ],
    targets: [
        .binaryTarget(name: "libdkls",
                      path: "Sources/libdkls/libdkls.xcframework"
        ),
        .target(name: "lib",
               dependencies: ["libdkls"],
                path: "Sources/libdkls"
        ),
        .target(
            name: "tss-client-swift",
            dependencies: ["BigInt", "CryptoSwift", "secp256k1", "SwiftKeccak", "SocketIO", "lib"]),
        .testTarget(
            name: "tss-client-swiftTests",
            dependencies: ["tss-client-swift", "BigInt"]),
    ]
)
