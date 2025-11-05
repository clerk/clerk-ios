//
//  VersionTests.swift
//
//
//  Created by Assistant on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct VersionTests {

  @Test
  func testClerkVersion() {
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
    // Device ID should be non-empty
    // Note: This test may behave differently on different platforms
    // On watchOS/macOS it returns "uidevice-unsupported"
    // On iOS it returns a UUID string or "none"
    let id = deviceID
    #expect(!id.isEmpty)

    // Should be either a UUID format or the unsupported string
    let isUUID = id.contains("-") && id.count == 36
    let isUnsupported = id == "uidevice-unsupported"
    let isNone = id == "none"

    #expect(isUUID || isUnsupported || isNone)
  }
}

