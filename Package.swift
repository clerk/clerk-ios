// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Clerk",
    platforms: [.iOS(.v16), .macCatalyst(.v16), .macOS(.v13), .watchOS(.v9), .tvOS(.v16), .visionOS(.v1)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ClerkSDK",
            targets: ["ClerkSDK"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-algorithms", .upToNextMajor(from: "1.2.0")),
        .package(url: "https://github.com/auth0/SimpleKeychain", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/kean/Get", .upToNextMajor(from: "2.1.6")),
//        .package(url: "https://github.com/hmlongco/Factory", branch: "swift6"),
        .package(url: "https://github.com/hmlongco/Factory", .upToNextMajor(from: "2.3.1")),
        .package(url: "https://github.com/kean/Nuke", .upToNextMajor(from: "12.1.6")),
        .package(url: "https://github.com/marmelroy/PhoneNumberKit", .upToNextMajor(from: "3.7.4"))
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ClerkSDK",
            dependencies: [
                .product(name: "Algorithms", package: "swift-algorithms"),
                "SimpleKeychain",
                "Get",
                "Factory",
                .product(name: "NukeUI", package: "Nuke"),
                "PhoneNumberKit"
            ],
            path: "Sources",
            exclude: [],
            swiftSettings: [
                // For < Swift 6.0 Tools
//                .enableExperimentalFeature("StrictConcurrency")
                // For >= Swift 6.0 Tools
//                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "ClerkTests",
            dependencies: ["ClerkSDK"],
            path: "Tests"
        ),
    ]
)
