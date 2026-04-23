//
//  ClerkHeaderRequestMiddlewareTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

@testable import ClerkKit
import Foundation
import Testing

/// Tests for ClerkHeaderRequestMiddleware header injection.
@MainActor
@Suite(.tags(.networking, .unit))
struct ClerkHeaderRequestMiddlewareTests {
  private func createMiddleware(
    clientId: String? = nil
  ) -> (keychain: InMemoryKeychain, middleware: ClerkHeaderRequestMiddleware) {
    let keychain = InMemoryKeychain()
    let middleware = ClerkHeaderRequestMiddleware(
      keychainProvider: { keychain },
      clientIdProvider: { clientId }
    )
    return (keychain, middleware)
  }

  @Test
  func addsDeviceTokenHeaderWhenPresent() async throws {
    let (keychain, middleware) = createMiddleware()
    try keychain.set("test-device-token", forKey: "clerkDeviceToken")
    var request = try URLRequest(url: #require(URL(string: "https://example.com")))

    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "Authorization") == "test-device-token")
  }

  @Test
  func doesNotAddDeviceTokenHeaderWhenMissing() async throws {
    let (_, middleware) = createMiddleware()
    var request = try URLRequest(url: #require(URL(string: "https://example.com")))

    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
  }

  @Test
  func addsClientIdHeaderWhenAvailable() async throws {
    let (_, middleware) = createMiddleware(clientId: Client.mock.id)
    var request = try URLRequest(url: #require(URL(string: "https://example.com")))

    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "x-clerk-client-id") == Client.mock.id)
  }

  @Test
  func doesNotAddClientIdHeaderWhenClientMissing() async throws {
    let (_, middleware) = createMiddleware()
    var request = try URLRequest(url: #require(URL(string: "https://example.com")))

    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "x-clerk-client-id") == nil)
  }

  @Test
  func addsNativeDeviceIdHeaderWhenAvailable() async throws {
    let (_, middleware) = createMiddleware()
    var request = try URLRequest(url: #require(URL(string: "https://example.com")))

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
    let (_, middleware) = createMiddleware()
    var request = try URLRequest(url: #require(URL(string: "https://example.com")))

    try await middleware.prepare(&request)

    let headerValue = request.value(forHTTPHeaderField: "x-device-type")
    #expect(headerValue != nil, "Should always include device type header")
    #expect(["ipad", "iphone", "mac", "carplay", "tv", "vision", "watch", "unspecified"].contains(headerValue ?? ""), "Device type should be one of the expected values")
  }

  @Test
  func addsDeviceInfoHeaders() async throws {
    let (_, middleware) = createMiddleware()
    var request = try URLRequest(url: #require(URL(string: "https://example.com")))

    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "x-device-model") != nil, "Should include device model header")
    #expect(request.value(forHTTPHeaderField: "x-os-version") != nil, "Should include OS version header")
    #expect(request.value(forHTTPHeaderField: "x-app-version") != nil, "Should include app version header")
    #expect(request.value(forHTTPHeaderField: "x-bundle-id") != nil, "Should include bundle ID header")
    #expect(request.value(forHTTPHeaderField: "x-is-sandbox") != nil, "Should include sandbox header")
    #expect(["true", "false"].contains(request.value(forHTTPHeaderField: "x-is-sandbox") ?? ""), "Sandbox should be true or false")
  }
}
