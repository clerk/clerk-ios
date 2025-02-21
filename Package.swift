// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Clerk",
    platforms: [
        .iOS(.v17),
        .macCatalyst(.v17),
        .macOS(.v14),
        .watchOS(.v10),
        .tvOS(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "Clerk", targets: ["Clerk"])
    ],
    dependencies: [
        .package(url: "https://github.com/hmlongco/Factory", .upToNextMajor(from: "2.4.3")),
        .package(url: "https://github.com/kean/Get", .upToNextMajor(from: "2.2.1")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(url: "https://github.com/auth0/SimpleKeychain", .upToNextMajor(from: "1.0.0"))
    ],
    targets: [
        .target(
            name: "Clerk",
            dependencies: [
                .product(name: "Factory", package: "Factory"),
                .product(name: "Get", package: "Get"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
                .product(name: "SimpleKeychain", package: "SimpleKeychain")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "ClerkTests",
            dependencies: [
                "Clerk"
            ]
        ),
    ]
)
