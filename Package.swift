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
    .library(name: "ClerkKitUI", targets: ["ClerkKitUI"])
  ],
  dependencies: [
    .package(url: "https://github.com/kean/Nuke.git", .upToNextMajor(from: "12.0.0")),
    .package(url: "https://github.com/marmelroy/PhoneNumberKit", .upToNextMajor(from: "4.0.0")),
    .package(url: "https://github.com/WeTransfer/Mocker", from: "3.0.0")
  ],
  targets: [
    .target(
      name: "ClerkKit",
      dependencies: [
      ],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ]
    ),
    .target(
      name: "ClerkKitUI",
      dependencies: [
        "ClerkKit",
        .product(name: "Nuke", package: "Nuke"),
        .product(name: "NukeUI", package: "Nuke"),
        .product(name: "PhoneNumberKit", package: "PhoneNumberKit")
      ],
      resources: [
        .process("Resources")
      ],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ]
    ),
    .testTarget(
      name: "Tests",
      dependencies: [
        "ClerkKit",
        .product(name: "Mocker", package: "Mocker")
      ],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ]
    )
  ]
)
