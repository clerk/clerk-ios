//
//  ClerkDeviceTokenResponseMiddlewareTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

/// Tests for ClerkDeviceTokenResponseMiddleware token extraction and storage.
@MainActor
@Suite(.serialized)
struct ClerkDeviceTokenResponseMiddlewareTests {

  init() {
    configureClerkForTesting()
  }

  @Test
  func testSavesDeviceTokenFromResponseHeader() async throws {
    let keychain = InMemoryKeychain()

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )

    let middleware = ClerkDeviceTokenResponseMiddleware()
    let request = URLRequest(url: URL(string: "https://example.com")!)
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: ["Authorization": "new-device-token-123"]
    )!

    try middleware.validate(response, data: Data(), for: request)

    let savedToken = try keychain.string(forKey: "clerkDeviceToken")
    #expect(savedToken == "new-device-token-123")
  }

  @Test
  func testDoesNotSaveTokenWhenHeaderMissing() async throws {
    let keychain = InMemoryKeychain()

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )

    // Set an initial token
    try keychain.set("original-token", forKey: "clerkDeviceToken")

    let middleware = ClerkDeviceTokenResponseMiddleware()
    let request = URLRequest(url: URL(string: "https://example.com")!)
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: [:]
    )!

    try middleware.validate(response, data: Data(), for: request)

    // Token should remain unchanged
    let savedToken = try keychain.string(forKey: "clerkDeviceToken")
    #expect(savedToken == "original-token")
  }

  @Test
  func testUpdatesExistingToken() async throws {
    let keychain = InMemoryKeychain()

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )

    // Set an initial token
    try keychain.set("old-token", forKey: "clerkDeviceToken")

    let middleware = ClerkDeviceTokenResponseMiddleware()
    let request = URLRequest(url: URL(string: "https://example.com")!)
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: ["Authorization": "new-token-456"]
    )!

    try middleware.validate(response, data: Data(), for: request)

    let savedToken = try keychain.string(forKey: "clerkDeviceToken")
    #expect(savedToken == "new-token-456")
  }
}
