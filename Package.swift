// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Clerk",
    platforms: [
        .iOS(.v16),
        .tvOS(.v16),
        .macOS(.v13),
        .watchOS(.v9)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Clerk",
            targets: ["Clerk"]),
    ], 
    dependencies: [
        .package(url: "https://github.com/kean/Get", from: "2.1.0"),
        .package(url: "https://github.com/CreateAPI/URLQueryEncoder", from: "0.2.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.2")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Clerk",
            dependencies: [
                "Get",
                "URLQueryEncoder",
                "KeychainAccess"
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "ClerkTests",
            dependencies: ["Clerk"], 
            path: "Tests"
        ),
    ]
)
