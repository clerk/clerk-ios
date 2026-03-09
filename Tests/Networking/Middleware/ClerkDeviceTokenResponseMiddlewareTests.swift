//
//  ClerkDeviceTokenResponseMiddlewareTests.swift
//  Clerk
//

@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkDeviceTokenResponseMiddlewareTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func extractsDeviceTokenFromAuthorizationHeader() async throws {
    let deviceToken = "test_device_token_12345"

    let response = HTTPURLResponse(
      url: URL(string: "https://api.clerk.test")!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: ["Authorization": deviceToken]
    )!

    let request = URLRequest(url: URL(string: "https://api.clerk.test")!)
    let middleware = ClerkDeviceTokenResponseMiddleware()

    try await middleware.validate(response, data: Data(), for: request)

    // Verify token was stored
    let storedToken = try Clerk.shared.dependencies.keychain.string(
      forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
    )
    #expect(storedToken == deviceToken)
  }

  @Test
  func handlesResponseWithoutAuthorizationHeader() async throws {
    let response = HTTPURLResponse(
      url: URL(string: "https://api.clerk.test")!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: [:]
    )!

    let request = URLRequest(url: URL(string: "https://api.clerk.test")!)
    let middleware = ClerkDeviceTokenResponseMiddleware()

    // Should not throw
    try await middleware.validate(response, data: Data(), for: request)
  }

  @Test
  func updatesExistingDeviceToken() async throws {
    // Set initial token
    let initialToken = "initial_token"
    try Clerk.shared.dependencies.keychain.set(
      initialToken,
      forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
    )

    // Receive new token
    let newToken = "new_device_token"
    let response = HTTPURLResponse(
      url: URL(string: "https://api.clerk.test")!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: ["Authorization": newToken]
    )!

    let request = URLRequest(url: URL(string: "https://api.clerk.test")!)
    let middleware = ClerkDeviceTokenResponseMiddleware()

    try await middleware.validate(response, data: Data(), for: request)

    // Verify new token was stored
    let storedToken = try Clerk.shared.dependencies.keychain.string(
      forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
    )
    #expect(storedToken == newToken)
  }

  @Test
  func storesEmptyTokenValue() async throws {
    let emptyToken = ""

    let response = HTTPURLResponse(
      url: URL(string: "https://api.clerk.test")!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: ["Authorization": emptyToken]
    )!

    let request = URLRequest(url: URL(string: "https://api.clerk.test")!)
    let middleware = ClerkDeviceTokenResponseMiddleware()

    try await middleware.validate(response, data: Data(), for: request)

    let storedToken = try Clerk.shared.dependencies.keychain.string(
      forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
    )
    #expect(storedToken == emptyToken)
  }
}