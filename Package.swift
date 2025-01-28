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
        .library(name: "Clerk", targets: ["Clerk"]),
        .library(name: "ClerkUI", targets: ["ClerkUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-algorithms", .upToNextMajor(from: "1.2.0")),
        .package(url: "https://github.com/auth0/SimpleKeychain", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/kean/Get", .upToNextMajor(from: "2.2.1")),
        .package(url: "https://github.com/hmlongco/Factory", .upToNextMajor(from: "2.4.3")),
        .package(url: "https://github.com/onevcat/Kingfisher", .upToNextMajor(from: "8.1.3")),
        .package(url: "https://github.com/marmelroy/PhoneNumberKit", .upToNextMajor(from: "3.7.4"))
    ],
    targets: [
        .target(
            name: "Clerk",
            dependencies: [
                .product(name: "Get", package: "Get"),
                .product(name: "Factory", package: "Factory"),
                .product(name: "SimpleKeychain", package: "SimpleKeychain")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "ClerkUI",
            dependencies: [
                "Clerk",
                .product(name: "Kingfisher", package: "Kingfisher"),
                .product(name: "PhoneNumberKit", package: "PhoneNumberKit"),
                .product(name: "Algorithms", package: "swift-algorithms")
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
