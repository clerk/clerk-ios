// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Clerk",
  defaultLocalization: "en",
  platforms: [
    .iOS(.v17),
    .macCatalyst(.v17),
    .macOS(.v14),
    .watchOS(.v10),
    .tvOS(.v17),
    .visionOS(.v1)
  ],
  products: [
    .library(name: "ClerkKit", targets: ["ClerkKit"]),
    .library(name: "ClerkKitUI", targets: ["ClerkKitUI"]),
    // Legacy product retained temporarily while the new modules are rolled out.
    .library(name: "Clerk", targets: ["Clerk"])
  ],
  dependencies: [
    .package(url: "https://github.com/hmlongco/Factory", from: "2.5.3"),
    .package(url: "https://github.com/kean/Get", .upToNextMajor(from: "2.2.1")),
    .package(url: "https://github.com/onevcat/Kingfisher.git", .upToNextMajor(from: "8.0.0")),
    .package(url: "https://github.com/kean/Nuke.git", .upToNextMajor(from: "12.0.0")),
    .package(url: "https://github.com/WeTransfer/Mocker.git", .upToNextMajor(from: "3.0.0")),
    .package(url: "https://github.com/marmelroy/PhoneNumberKit", .upToNextMajor(from: "4.0.0")),
    .package(url: "https://github.com/auth0/SimpleKeychain", .upToNextMajor(from: "1.0.0")),
    .package(url: "https://github.com/pointfreeco/swift-concurrency-extras", .upToNextMajor(from: "1.3.1"))
  ],
  targets: [
    .target(
      name: "ClerkKit",
      dependencies: [
        .product(name: "FactoryKit", package: "Factory"),
        .product(name: "Get", package: "Get"),
        .product(name: "SimpleKeychain", package: "SimpleKeychain")
      ],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ]
    ),
    .target(
      name: "ClerkKitUI",
      dependencies: [
        "ClerkKit",
        .product(name: "FactoryKit", package: "Factory"),
        .product(name: "Kingfisher", package: "Kingfisher"),
        .product(name: "Nuke", package: "Nuke"),
        .product(name: "PhoneNumberKit", package: "PhoneNumberKit")
      ],
      resources: [
        .process("Resources")
      ],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ]
    ),
    .target(
      name: "Clerk",
      dependencies: [
        "ClerkKit",
        "ClerkKitUI"
      ],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ]
    ),
    .testTarget(
      name: "ClerkTests",
      dependencies: [
        "Clerk",
        .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
        .product(name: "Mocker", package: "Mocker")
      ],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ]
    ),
  ]
)
