@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.networking, .unit))
struct ClientServiceTests {
  private func makeService(baseURL: URL) -> ClientService {
    ClientService(apiClient: createIsolatedMockAPIClient(baseURL: baseURL, protocolClass: IsolatedMockURLProtocol.self))
  }

  @Test
  func testGetResponse() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client")

    try registerIsolatedStub(
      url: originalURL,
      method: .get,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<Client?>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "GET")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).getResponse()
    #expect(requestHandled.value)
  }

  @Test
  func getResponseIncludesRequestSequence() async throws {
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client")

    try registerIsolatedStub(
      url: originalURL,
      method: .get,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<Client?>(response: .mock, client: .mock))
    )
    defer { removeIsolatedStub(for: originalURL) }

    let response = try await makeService(baseURL: baseURL).getResponse()

    #expect(response.client?.id == Client.mock.id)
    #expect(response.requestSequence == 1)
  }
}
