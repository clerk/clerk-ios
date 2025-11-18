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
  func addsNativeDeviceIdHeaderWhenAvailable() async throws {
    let middleware = ClerkHeaderRequestMiddleware()
    var request = URLRequest(url: URL(string: "https://example.com")!)

    try await middleware.prepare(&request)

    if let deviceId = DeviceHelper.deviceID {
      let headerValue = request.value(forHTTPHeaderField: "x-native-device-id")
      #expect(headerValue != nil, "Should include device ID header when available")
      #expect(headerValue == deviceId)
    } else {
      let headerValue = request.value(forHTTPHeaderField: "x-native-device-id")
      #expect(headerValue == nil, "Should not include device ID header when unavailable")
    }
  }

  @Test
  func addsDeviceTypeHeader() async throws {
    let middleware = ClerkHeaderRequestMiddleware()
    var request = URLRequest(url: URL(string: "https://example.com")!)

    try await middleware.prepare(&request)

    let headerValue = request.value(forHTTPHeaderField: "x-device-type")
    #expect(headerValue != nil, "Should always include device type header")
    #expect(["ipad", "iphone", "mac", "carplay", "tv", "vision", "watch", "unspecified"].contains(headerValue ?? ""), "Device type should be one of the expected values")
  }

  @Test
  func addsDeviceInfoHeaders() async throws {
    let middleware = ClerkHeaderRequestMiddleware()
    var request = URLRequest(url: URL(string: "https://example.com")!)

    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "x-device-model") != nil, "Should include device model header")
    #expect(request.value(forHTTPHeaderField: "x-os-version") != nil, "Should include OS version header")
    #expect(request.value(forHTTPHeaderField: "x-app-version") != nil, "Should include app version header")
    #expect(request.value(forHTTPHeaderField: "x-bundle-id") != nil, "Should include bundle ID header")
    #expect(request.value(forHTTPHeaderField: "x-is-sandbox") != nil, "Should include sandbox header")
    #expect(["true", "false"].contains(request.value(forHTTPHeaderField: "x-is-sandbox") ?? ""), "Sandbox should be true or false")
  }
}
