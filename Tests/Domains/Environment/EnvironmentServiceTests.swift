@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@MainActor
@Suite(.serialized)
struct EnvironmentServiceTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func testGet() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/environment")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(Clerk.Environment.mock),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.environmentService.get()
    #expect(requestHandled.value)
  }

  @Test
  func getWithoutFraudSettings() async throws {
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/environment")!
    let encodedEnvironment = try JSONEncoder.clerkEncoder.encode(Clerk.Environment.mock)
    var jsonObject = try #require(JSONSerialization.jsonObject(with: encodedEnvironment) as? [String: Any])
    jsonObject.removeValue(forKey: "fraud_settings")

    let mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONSerialization.data(withJSONObject: jsonObject),
      ]
    )

    mock.register()

    let environment = try await Clerk.shared.dependencies.environmentService.get()
    #expect(environment.fraudSettings == .init())
  }
}
