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
    if let id = DeviceHelper.deviceID {
      let isUUID = id.contains("-") && id.count == 36
      #expect(isUUID, "Device ID should be a valid UUID when available")
    }
  }
}
