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

  @Test
  func validateRejectsProvablyNewerTokenAcrossSharedIdentityFence() async throws {
    configureClerkForTesting()
    let keychain = InMemoryKeychain()
    try keychain.set("current-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    clerk.applyResponseClient(
      Client.mock,
      responseSequence: 1,
      serverDate: Date(timeIntervalSince1970: 200)
    )
    let requestGeneration = clerk.clientResponseGeneration
    clerk.fenceClientResponsesAfterSharedIdentityChange()

    let middleware = ClerkDeviceTokenResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))
    let url = try #require(URL(string: "https://example.com/v1/client"))
    let response = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: [
        "Authorization": "new-token",
        "Date": "Thu, 01 Jan 1970 00:05:00 GMT",
      ]
    ))
    var request = URLRequest(url: url)
    request.setClerkClientResponseGeneration(requestGeneration)

    try await middleware.validate(response, data: Data(), for: request)

    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "current-token")
  }

  @Test
  func validateRejectsOlderTokenAcrossSharedIdentityFence() async throws {
    configureClerkForTesting()
    let keychain = InMemoryKeychain()
    try keychain.set("current-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    clerk.applyResponseClient(
      Client.mock,
      responseSequence: 1,
      serverDate: Date(timeIntervalSince1970: 200)
    )
    let requestGeneration = clerk.clientResponseGeneration
    clerk.fenceClientResponsesAfterSharedIdentityChange()

    let middleware = ClerkDeviceTokenResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))
    let url = try #require(URL(string: "https://example.com/v1/client"))
    let response = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: [
        "Authorization": "stale-token",
        "Date": "Thu, 01 Jan 1970 00:01:40 GMT",
      ]
    ))
    var request = URLRequest(url: url)
    request.setClerkClientResponseGeneration(requestGeneration)

    try await middleware.validate(response, data: Data(), for: request)

    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "current-token")
  }

  @Test
  func validateDefersTokenWhenClientFieldCannotBeDecoded() async throws {
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
    let data = try #require("""
    {"client":{"object":"client"}}
    """.data(using: .utf8))

    try await middleware.validate(response, data: data, for: URLRequest(url: url))

    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "current-token")
  }

  @Test
  func validateStoresDeviceTokenWithoutClearingClientWhenErrorMetaClientIsNull() async throws {
    configureClerkForTesting()
    let keychain = InMemoryKeychain()
    try keychain.set("current-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    let existingClient = Client.mock
    clerk.client = existingClient
    let deviceTokenMiddleware = ClerkDeviceTokenResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))
    let clientSyncMiddleware = ClerkClientSyncResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))
    let url = try #require(URL(string: "https://example.com/v1/client/sign_ins"))
    let response = try #require(HTTPURLResponse(
      url: url,
      statusCode: 400,
      httpVersion: nil,
      headerFields: ["Authorization": "new-token"]
    ))
    let data = try #require("""
    {"errors":[],"meta":{"client":null}}
    """.data(using: .utf8))
    let request = URLRequest(url: url)

    try await deviceTokenMiddleware.validate(response, data: data, for: request)
    try await clientSyncMiddleware.validate(response, data: data, for: request)

    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "new-token")
    #expect(clerk.client?.id == existingClient.id)
  }
}
