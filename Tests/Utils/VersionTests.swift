//
//  VersionTests.swift
//

@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct VersionTests {
  @Test
  func clerkVersion() {
    // Version should be a non-empty string
    #expect(!Clerk.sdkVersion.isEmpty)

    // Version should follow semantic versioning format (x.y.z)
    let parts = Clerk.sdkVersion.split(separator: ".")
    #expect(parts.count >= 2) // At least major.minor

    // Each part should be numeric
    for part in parts {
      #expect(part.allSatisfy { $0.isNumber })
    }
  }

  @Test
  func testDeviceID() {
    // Device ID may be nil on watchOS/macOS or when unavailable
    // On iOS it returns a UUID string or nil
    if let id = DeviceHelper.deviceID {
      // Should be a UUID format
      let isUUID = id.contains("-") && id.count == 36
      #expect(isUUID, "Device ID should be a valid UUID when available")
    }
    // It's acceptable for deviceID to be nil on unsupported platforms
  }

  @Test
  func apiVersionIsNotEmpty() {
    #expect(!Clerk.apiVersion.isEmpty)
  }

  @Test
  func apiVersionHasDateFormat() {
    // API version should be in format YYYY-MM-DD
    let components = Clerk.apiVersion.split(separator: "-")
    #expect(components.count == 3, "API version should have 3 components separated by -")

    // Year should be 4 digits
    #expect(components[0].count == 4, "Year should be 4 digits")
    #expect(Int(components[0]) != nil, "Year should be numeric")

    // Month should be 2 digits
    #expect(components[1].count == 2, "Month should be 2 digits")
    #expect(Int(components[1]) != nil, "Month should be numeric")

    // Day should be 2 digits
    #expect(components[2].count == 2, "Day should be 2 digits")
    #expect(Int(components[2]) != nil, "Day should be numeric")
  }

  @Test
  func apiVersionIsValidDate() {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    let date = formatter.date(from: Clerk.apiVersion)

    #expect(date != nil, "API version should be a valid date")
  }

  @Test
  func sdkVersionMatchesSemverPattern() {
    // Version should match semver pattern
    let pattern = #"^\d+\.\d+\.\d+$"#
    let regex = try? NSRegularExpression(pattern: pattern)
    let range = NSRange(Clerk.sdkVersion.startIndex..., in: Clerk.sdkVersion)
    let match = regex?.firstMatch(in: Clerk.sdkVersion, range: range)

    #expect(match != nil, "SDK version should match semver pattern (X.Y.Z)")
  }

  @Test
  func versionsAreAccessible() {
    // Test that versions can be accessed
    let sdkVersion = Clerk.sdkVersion
    let apiVersion = Clerk.apiVersion

    #expect(!sdkVersion.isEmpty)
    #expect(!apiVersion.isEmpty)
  }
}