// swift-tools-version: 6.2
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
    .visionOS(.v1),
  ],
  products: [
    .library(name: "ClerkKit", targets: ["ClerkKit"]),
    .library(name: "ClerkKitUI", targets: ["ClerkKitUI"]),
    .library(name: "ClerkWatchCompanion", targets: ["ClerkWatchCompanion"]),
  ],
  dependencies: [
    .package(url: "https://github.com/kean/Nuke.git", .upToNextMajor(from: "13.0.6")),
    .package(url: "https://github.com/PhoneNumberKit/PhoneNumberKit", .upToNextMajor(from: "5.0.0")),
    .package(url: "https://github.com/WeTransfer/Mocker", from: "3.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-concurrency-extras", from: "1.1.0"),
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.19.4"),
  ],
  targets: [
    .target(
      name: "ClerkSnapshots",
      dependencies: [],
      path: "Sources/ClerkSnapshots",
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency"),
      ]
    ),
    .target(
      name: "ClerkJSCore",
      dependencies: ["ClerkSnapshots", "ClerkWatchCompanion"],
      path: "Sources/ClerkJSCore",
      resources: [
        .process("Resources"),
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency"),
      ],
      linkerSettings: [
        .linkedFramework(
          "JavaScriptCore",
          .when(platforms: [.iOS, .macCatalyst, .macOS, .tvOS, .visionOS])
        ),
      ]
    ),
    .target(
      name: "ClerkWatchCompanion",
      dependencies: ["ClerkSnapshots"],
      path: "Sources/ClerkWatchCompanion",
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency"),
      ]
    ),
    .target(
      name: "ClerkKit",
      dependencies: ["ClerkSnapshots"],
      path: "Sources/ClerkKit",
      resources: [
        .process("Resources"),
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency"),
      ]
    ),
    .target(
      name: "ClerkKitUI",
      dependencies: [
        "ClerkKit",
        "ClerkJSCore",
        .product(name: "Nuke", package: "Nuke"),
        .product(name: "NukeUI", package: "Nuke"),
        .product(name: "PhoneNumberKit", package: "PhoneNumberKit"),
      ],
      path: "Sources/ClerkKitUI",
      resources: [
        .process("Resources"),
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency"),
      ]
    ),
    .testTarget(
      name: "ClerkKitTests",
      dependencies: [
        "ClerkKit",
        "ClerkKitUI",
        .product(name: "Mocker", package: "Mocker"),
        .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
      ],
      path: "Tests",
      exclude: [
        "UI",
        "ClerkJSCore",
        "ClerkJSCoreIntegration",
        "ClerkWatchCompanion",
      ],
      resources: [
        .process("Resources"),
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency"),
      ]
    ),
    .testTarget(
      name: "ClerkKitUITests",
      dependencies: [
        "ClerkKit",
        "ClerkKitUI",
        "ClerkJSCore",
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
      ],
      path: "Tests/UI",
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency"),
      ]
    ),
    .testTarget(
      name: "ClerkJSCoreTests",
      dependencies: [
        "ClerkJSCore",
        "ClerkWatchCompanion",
      ],
      path: "Tests/ClerkJSCore",
      resources: [
        .process("Fixtures"),
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency"),
      ]
    ),
    .testTarget(
      name: "ClerkJSCoreIntegrationTests",
      dependencies: [
        "ClerkJSCore",
      ],
      path: "Tests/ClerkJSCoreIntegration",
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency"),
      ]
    ),
    .testTarget(
      name: "ClerkWatchCompanionTests",
      dependencies: [
        "ClerkWatchCompanion",
      ],
      path: "Tests/ClerkWatchCompanion",
      resources: [
        .process("Fixtures"),
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency"),
      ]
    ),
  ]
)
