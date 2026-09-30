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
    #expect(!Clerk.sdkVersion.isEmpty)

    let parts = Clerk.sdkVersion.split(separator: ".")
    #expect(parts.count >= 2)

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
}
