//
//  RedirectConfigTests.swift
//

@testable import ClerkKit
import Foundation
import Testing

@Suite(.serialized)
struct RedirectConfigTests {
  @Test
  func defaultInitialization() {
    let config = Clerk.Options.RedirectConfig()
    let bundleId = Bundle.main.bundleIdentifier ?? ""

    #expect(config.redirectUrl == "\(bundleId)://callback")
    #expect(config.callbackUrlScheme == bundleId)
  }
}
