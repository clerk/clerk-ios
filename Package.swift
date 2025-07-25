// swift-tools-version: 5.9
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
    .library(name: "Clerk", targets: ["Clerk"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-algorithms", from: "1.2.0"),
    .package(url: "https://github.com/hmlongco/Factory", from: "2.5.3"),
    .package(url: "https://github.com/kean/Get", .upToNextMajor(from: "2.2.1")),
    .package(url: "https://github.com/onevcat/Kingfisher.git", .upToNextMajor(from: "8.0.0")),
    .package(url: "https://github.com/WeTransfer/Mocker.git", .upToNextMajor(from: "3.0.0")),
    .package(url: "https://github.com/marmelroy/PhoneNumberKit", .upToNextMajor(from: "4.0.0")),
    .package(url: "https://github.com/hmlongco/RequestBuilder", branch: "main"),
    .package(url: "https://github.com/auth0/SimpleKeychain", .upToNextMajor(from: "1.0.0")),
    .package(url: "https://github.com/pointfreeco/swift-concurrency-extras", .upToNextMajor(from: "1.3.1")),
  ],
  targets: [
    .target(
      name: "Clerk",
      dependencies: [
        .product(name: "Algorithms", package: "swift-algorithms"),
        .product(name: "FactoryKit", package: "Factory"),
        .product(name: "Get", package: "Get"),
        .product(name: "Kingfisher", package: "Kingfisher"),
        .product(name: "PhoneNumberKit", package: "PhoneNumberKit"),
        .product(name: "RequestBuilder", package: "RequestBuilder"),
        .product(name: "SimpleKeychain", package: "SimpleKeychain")
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
        .product(name: "Mocker", package: "Mocker"),
      ],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ]
    ),
  ]
)
