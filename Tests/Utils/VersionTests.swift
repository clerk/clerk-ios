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
  func sdkVersionHasExpectedValue() {
    // Regression test to ensure version is correctly set
    #expect(Clerk.sdkVersion == "1.0.4")
  }

  @Test
  func apiVersionIsNonEmpty() {
    // API version should be a non-empty string
    #expect(!Clerk.apiVersion.isEmpty)
  }

  @Test
  func apiVersionHasExpectedValue() {
    // Regression test to ensure API version is correctly set
    #expect(Clerk.apiVersion == "2025-11-10")
  }

  @Test
  func apiVersionFollowsDateFormat() {
    // API version should follow YYYY-MM-DD format
    let parts = Clerk.apiVersion.split(separator: "-")
    #expect(parts.count == 3)

    // Year should be 4 digits
    #expect(parts[0].count == 4)
    #expect(parts[0].allSatisfy { $0.isNumber })

    // Month should be 2 digits
    #expect(parts[1].count == 2)
    #expect(parts[1].allSatisfy { $0.isNumber })

    // Day should be 2 digits
    #expect(parts[2].count == 2)
    #expect(parts[2].allSatisfy { $0.isNumber })
  }

  @Test
  func sdkVersionIsNonisolated() {
    // Verify that sdkVersion can be accessed from a nonisolated context
    nonisolated func accessVersion() -> String {
      Clerk.sdkVersion
    }
    #expect(!accessVersion().isEmpty)
  }

  @Test
  func apiVersionIsNonisolated() {
    // Verify that apiVersion can be accessed from a nonisolated context
    nonisolated func accessAPIVersion() -> String {
      Clerk.apiVersion
    }
    #expect(!accessAPIVersion().isEmpty)
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
}