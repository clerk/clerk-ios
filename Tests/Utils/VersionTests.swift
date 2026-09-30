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
  func testDeviceID() throws {
    #if os(watchOS) || os(macOS)
    #expect(DeviceHelper.deviceID == nil)
    #else
    let id = try #require(DeviceHelper.deviceID)
    #expect(UUID(uuidString: id) != nil)
    #endif
  }
}
