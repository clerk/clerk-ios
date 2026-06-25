@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkDeviceTokenResponseMiddlewareTests {
  @Test
  func validateStoresDeviceTokenHeader() async throws {
    configureClerkForTesting()
    let keychain = InMemoryKeychain()
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    let middleware = ClerkDeviceTokenResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))
    let url = try #require(URL(string: "https://example.com/v1/client"))
    let response = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: ["Authorization": "new-token"]
    ))
    var request = URLRequest(url: url)
    request.setClerkClientResponseGeneration(clerk.clientResponseGeneration)

    try await middleware.validate(response, data: Data(), for: request)

    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "new-token")
  }

  @Test
  func validateSkipsDeviceTokenHeaderWhenPersistenceSuppressed() async throws {
    configureClerkForTesting()
    let keychain = InMemoryKeychain()
    try keychain.set("current-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    let middleware = ClerkDeviceTokenResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))
    let url = try #require(URL(string: "https://example.com/v1/client"))
    let response = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: ["Authorization": "new-token"]
    ))
    var request = URLRequest(url: url)
    request.setClerkClientResponseGeneration(clerk.clientResponseGeneration)
    request.setClerkSuppressesDeviceTokenPersistence(true)

    try await middleware.validate(response, data: Data(), for: request)

    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "current-token")
  }

  @Test
  func validateIgnoresDeviceTokenHeaderFromStaleDeviceTokenGeneration() async throws {
    configureClerkForTesting()
    let keychain = InMemoryKeychain()
    try keychain.set("current-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    let middleware = ClerkDeviceTokenResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))
    let url = try #require(URL(string: "https://example.com/v1/client"))
    let response = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: ["Authorization": "stale-token"]
    ))
    var request = URLRequest(url: url)
    request.setClerkClientResponseGeneration(clerk.clientResponseGeneration)

    clerk.clearCachedClientStateAfterDeviceTokenChange()

    try await middleware.validate(response, data: Data(), for: request)

    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "current-token")
  }
}
