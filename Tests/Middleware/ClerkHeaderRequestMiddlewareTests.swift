//
//  ClerkHeaderRequestMiddlewareTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

/// Tests for ClerkHeaderRequestMiddleware header injection.
@MainActor
@Suite(.serialized)
struct ClerkHeaderRequestMiddlewareTests {

  init() {
    configureClerkForTesting()
  }

  @Test
  func testAddsDeviceTokenHeaderWhenPresent() async throws {
    let keychain = InMemoryKeychain()
    try keychain.set("test-device-token", forKey: "clerkDeviceToken")

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )

    let middleware = ClerkHeaderRequestMiddleware()
    var request = URLRequest(url: URL(string: "https://example.com")!)

    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "Authorization") == "test-device-token")
  }

  @Test
  func testDoesNotAddDeviceTokenHeaderWhenMissing() async throws {
    let keychain = InMemoryKeychain()

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )

    let middleware = ClerkHeaderRequestMiddleware()
    var request = URLRequest(url: URL(string: "https://example.com")!)

    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
  }

  @Test
  func testAddsClientIdHeaderInDebugMode() async throws {
    // Configure Clerk with debug mode
    Clerk._reconfigure(
      publishableKey: testPublishableKey,
      options: Clerk.ClerkOptions(debugMode: true)
    )

    setupMockAPIClient()

    // Set a mock client
    Clerk.shared.client = .mock

    let middleware = ClerkHeaderRequestMiddleware()
    var request = URLRequest(url: URL(string: "https://example.com")!)

    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "x-clerk-client-id") == Client.mock.id)
  }

  @Test
  func testDoesNotAddClientIdHeaderWhenNotInDebugMode() async throws {
    // Configure Clerk without debug mode
    Clerk._reconfigure(
      publishableKey: testPublishableKey,
      options: Clerk.ClerkOptions(debugMode: false)
    )

    setupMockAPIClient()

    Clerk.shared.client = .mock

    let middleware = ClerkHeaderRequestMiddleware()
    var request = URLRequest(url: URL(string: "https://example.com")!)

    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "x-clerk-client-id") == nil)
  }

  @Test
  func testAddsNativeDeviceIdHeader() async throws {
    let middleware = ClerkHeaderRequestMiddleware()
    var request = URLRequest(url: URL(string: "https://example.com")!)

    try await middleware.prepare(&request)

    let deviceId = request.value(forHTTPHeaderField: "x-native-device-id")
    #expect(deviceId != nil, "Should always include device ID header")
    #expect(deviceId?.isEmpty == false)
  }
}

