@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkDeviceTokenResponseMiddlewareTests {
  @Test
  func clientSyncMiddlewareStoresTokenOnlyResponse() async throws {
    configureClerkForTesting()
    let keychain = InMemoryKeychain()
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    let middleware = ClerkClientSyncResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))
    let url = try #require(URL(string: "https://example.com/v1/client/sessions"))
    let response = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: ["Authorization": "new-token"]
    ))
    var request = URLRequest(url: url)
    request.setClerkClientResponseGeneration(clerk.clientResponseGeneration)
    request.setClerkRequestSequence(1)

    try await middleware.validate(response, data: Data("{}".utf8), for: request)

    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "new-token")
  }

  @Test
  func lateResponseCannotRestoreTokenAfterNewerClear() async throws {
    configureClerkForTesting()
    let keychain = InMemoryKeychain()
    try keychain.set("current-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    clerk.client = Client.mock
    let middleware = ClerkClientSyncResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))
    let url = try #require(URL(string: "https://example.com/v1/client"))
    let requestGeneration = clerk.clientResponseGeneration
    let responseData = try JSONEncoder.clerkEncoder.encode(
      ClientResponse<Client>(response: Client.mock, client: nil)
    )

    var newerRequest = URLRequest(url: url)
    newerRequest.setValue("current-token", forHTTPHeaderField: "Authorization")
    newerRequest.setClerkClientResponseGeneration(requestGeneration)
    newerRequest.setClerkRequestSequence(2)
    let newerResponse = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: ["Authorization": "Bearer "]
    ))
    try await middleware.validate(newerResponse, data: responseData, for: newerRequest)

    var olderRequest = URLRequest(url: url)
    olderRequest.setValue("current-token", forHTTPHeaderField: "Authorization")
    olderRequest.setClerkClientResponseGeneration(requestGeneration)
    olderRequest.setClerkRequestSequence(1)
    let olderResponse = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: ["Authorization": "stale-token"]
    ))
    try await middleware.validate(olderResponse, data: responseData, for: olderRequest)

    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == nil)
    #expect(clerk.client == nil)
  }

  @Test
  func staleDeviceTokenGenerationCannotUpdateToken() async throws {
    configureClerkForTesting()
    let keychain = InMemoryKeychain()
    try keychain.set("current-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    let middleware = ClerkClientSyncResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))
    let url = try #require(URL(string: "https://example.com/v1/client/sessions"))
    let response = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: ["Authorization": "stale-token"]
    ))
    var request = URLRequest(url: url)
    request.setClerkClientResponseGeneration(clerk.clientResponseGeneration)
    request.setClerkRequestSequence(1)

    clerk.identityController.clearCachedClientStateAfterDeviceTokenChange()
    try await middleware.validate(response, data: Data("{}".utf8), for: request)

    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "current-token")
  }
}
