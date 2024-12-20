// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "tss-client-swift",
    platforms: [.iOS(.v14), .macOS(.v10_15)],
    products: [
        .library(
            name: "tssClientSwift",
            targets: ["tssClientSwift"]),
    ],
    dependencies: [
        .package(name: "BigInt", url: "https://github.com/attaswift/BigInt.git", from: "5.3.0"),
        .package(name: "curvelib.swift", url: "https://github.com/tkey/curvelib.swift", from: "2.0.0"),
        .package(name: "SocketIO", url: "https://github.com/socketio/socket.io-client-swift", from: "16.1.1"),
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
            name: "tssClientSwift",
            dependencies: ["BigInt", .product(name: "curveSecp256k1", package: "curvelib.swift"), "SocketIO", "dkls"],
            path: "Sources/tssClientSwift"),
        .testTarget(
            name: "tss-client-swiftTests",
            dependencies: ["tssClientSwift", "BigInt"]),
    ]
)
