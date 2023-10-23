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
            name: "Clerk",
            targets: ["Clerk"]),
        .library(
            name: "ClerkUI",
            targets: ["ClerkUI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.2"),
        .package(url: "https://github.com/CreateAPI/URLQueryEncoder", from: "0.2.1"),
        .package(url: "https://github.com/kean/Get", from: "2.1.6"),
        .package(url: "https://github.com/hmlongco/Factory", from: "2.3.1"),
        .package(url: "https://github.com/kean/Nuke", from: "12.1.6"),
        .package(url: "https://github.com/marmelroy/PhoneNumberKit", from: "3.7.4")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Clerk",
            dependencies: [
                "KeychainAccess",
                "URLQueryEncoder",
                "Get",
                "Factory"
            ],
            path: "Sources/FrontendAPI"
        ),
        .target(
            name: "ClerkUI",
            dependencies: [
                "Clerk",
                .product(name: "NukeUI", package: "Nuke"),
                "PhoneNumberKit"
            ],
            path: "Sources/UI"
        ),
        .testTarget(
            name: "ClerkTests",
            dependencies: ["Clerk"], 
            path: "Tests"
        ),
    ]
)
