@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@MainActor
@Suite(.serialized)
struct UserUpdateMetadataTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func updateMetadataParamsHitsMetadataEndpoint() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/metadata")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .patch: JSONEncoder.clerkEncoder.encode(ClientResponse<User>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.url?.path == "/v1/me/metadata")
      #expect(request.allHTTPHeaderFields?["Content-Type"] == "application/x-www-form-urlencoded")
      #expect(request.urlEncodedFormBody!["unsafe_metadata"] == "{\"theme\":\"dark\"}")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.userService.updateMetadata(
      params: .init(unsafeMetadata: ["theme": "dark"])
    )
    #expect(requestHandled.value)
  }

  @Test
  func jsonObjectOverloadProducesSameRequestShapeAsParamsVariant() async throws {
    let captured = LockIsolated<User.UpdateMetadataParams?>(nil)
    let service = MockUserService(updateMetadata: { params in
      captured.setValue(params)
      return .mock
    })
    configureService(service)

    _ = try await User.mock.updateMetadata(unsafeMetadata: ["k": "v"])

    let params = try #require(captured.value)
    #expect(params.unsafeMetadata == ["k": "v"])
  }

  @Test
  func nullValuesInPatchReachTheWireAsLiteralNull() async throws {
    // Critical correctness check: if `ClerkURLEncodedFormEncoderMiddleware` silently
    // drops top-level `.null` values when serializing the body, null-deletes never
    // reach FAPI and `update({unsafeMetadata})` quietly becomes merge-only.
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/metadata")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .patch: JSONEncoder.clerkEncoder.encode(ClientResponse<User>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      let body = request.urlEncodedFormBody!["unsafe_metadata"]
      // The stringified JSON must contain a literal `null` value for `removed`.
      #expect(body?.contains("\"removed\":null") == true,
              "Expected literal null in unsafe_metadata; got: \(body ?? "nil")")
      #expect(body?.contains("\"kept\":\"yes\"") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.userService.updateMetadata(
      params: .init(unsafeMetadata: ["kept": "yes", "removed": .null])
    )
    #expect(requestHandled.value)
  }

  // MARK: - Helpers

  private func configureService(_ service: MockUserService) {
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      userService: service
    )
    try! (Clerk.shared.dependencies as! MockDependencyContainer)
      .configurationManager
      .configure(publishableKey: testPublishableKey, options: .init())
  }
}
