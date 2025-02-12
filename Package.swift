// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "listen",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: Version(1, 5, 0)))
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(name: "libListen"),
        .testTarget(
            name: "libListenTests",
            dependencies: [
                "libListen"
            ]),
        .executableTarget(
            name: "listen",
            dependencies: [
                "libListen",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]),
    ]
)
