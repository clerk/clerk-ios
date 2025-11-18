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

  /// Creates a test setup with a fresh keychain and configured dependencies.
  ///
  /// - Returns: A fresh InMemoryKeychain instance.
  private func createTestKeychain() -> InMemoryKeychain {
    let keychain = InMemoryKeychain()

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )

    return keychain
  }

  @Test
  func addsDeviceTokenHeaderWhenPresent() async throws {
    let keychain = createTestKeychain()
    try keychain.set("test-device-token", forKey: "clerkDeviceToken")

    let middleware = ClerkHeaderRequestMiddleware()
    var request = URLRequest(url: URL(string: "https://example.com")!)

    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "Authorization") == "test-device-token")
  }

  @Test
  func doesNotAddDeviceTokenHeaderWhenMissing() async throws {
    _ = createTestKeychain()

    let middleware = ClerkHeaderRequestMiddleware()
    var request = URLRequest(url: URL(string: "https://example.com")!)

    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
  }

  @Test
  func addsClientIdHeaderWhenAvailable() async throws {
    // Set a mock client
    Clerk.shared.client = .mock

    let middleware = ClerkHeaderRequestMiddleware()
    var request = URLRequest(url: URL(string: "https://example.com")!)

    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "x-clerk-client-id") == Client.mock.id)
  }

  @Test
  func doesNotAddClientIdHeaderWhenClientMissing() async throws {
    // Ensure no client is set
    Clerk.shared.client = nil

    let middleware = ClerkHeaderRequestMiddleware()
    var request = URLRequest(url: URL(string: "https://example.com")!)

    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "x-clerk-client-id") == nil)
  }

  @Test
  func addsNativeDeviceIdHeader() async throws {
    let middleware = ClerkHeaderRequestMiddleware()
    var request = URLRequest(url: URL(string: "https://example.com")!)

    try await middleware.prepare(&request)

    let deviceId = request.value(forHTTPHeaderField: "x-native-device-id")
    #expect(deviceId != nil, "Should always include device ID header")
    #expect(deviceId?.isEmpty == false)
  }
}
