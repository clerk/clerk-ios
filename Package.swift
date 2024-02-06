// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Clerk",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ClerkSDK",
            targets: ["ClerkSDK"]),
        .library(
            name: "ClerkUISDK",
            targets: ["ClerkUISDK"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-algorithms", .upToNextMajor(from: "1.2.0")),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", .upToNextMajor(from: "4.2.2")),
        .package(url: "https://github.com/CreateAPI/URLQueryEncoder", .upToNextMajor(from: "0.2.1")),
        .package(url: "https://github.com/kean/Get", .upToNextMajor(from: "2.1.6")),
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
                "KeychainAccess",
                "URLQueryEncoder",
                "Get",
                "Factory"
            ],
            path: "Sources/API"
        ),
        .target(
            name: "ClerkUISDK",
            dependencies: [
                "ClerkSDK",
                .product(name: "NukeUI", package: "Nuke"),
                "PhoneNumberKit"
            ],
            path: "Sources/UI"
        ),
        .testTarget(
            name: "ClerkTests",
            dependencies: ["ClerkSDK"],
            path: "Tests"
        ),
    ]
)
