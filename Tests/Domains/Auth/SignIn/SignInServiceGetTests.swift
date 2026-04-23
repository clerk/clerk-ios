@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.networking, .unit))
struct SignInServiceGetTests {
  private func makeService(baseURL: URL) -> SignInService {
    SignInService(apiClient: createIsolatedMockAPIClient(baseURL: baseURL, protocolClass: IsolatedMockURLProtocol.self))
  }

  @Test
  func testGet() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ins/\(signIn.id)")

    try registerIsolatedStub(
      url: originalURL,
      method: .get,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "GET")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).get(
      signInId: signIn.id,
      params: .init()
    )
    #expect(requestHandled.value)
  }

  @Test
  func getWithRotatingTokenNonce() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ins/\(signIn.id)")

    try registerIsolatedStub(
      url: originalURL,
      method: .get,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("rotating_token_nonce=test_nonce") == true)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).get(
      signInId: signIn.id,
      params: .init(rotatingTokenNonce: "test_nonce")
    )
    #expect(requestHandled.value)
  }
}
