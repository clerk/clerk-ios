@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.networking, .unit))
struct UserServiceAccountTests {
  private let sessionId = "session_test_123"

  private func makeService(baseURL: URL) -> UserService {
    let apiClient = createIsolatedMockAPIClient(baseURL: baseURL, protocolClass: IsolatedMockURLProtocol.self)
    return UserService(apiClient: apiClient)
  }

  @Test
  func testReload() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me")

    try registerIsolatedStub(
      url: originalURL,
      method: .get,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<User>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "GET")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).reload(sessionId: sessionId)
    #expect(requestHandled.value)
  }

  @Test
  func testUpdate() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me")

    try registerIsolatedStub(
      url: originalURL,
      method: .patch,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<User>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.allHTTPHeaderFields?["Content-Type"] == "application/x-www-form-urlencoded")
      #expect(request.urlEncodedFormBody!["first_name"] == "John")
      #expect(request.urlEncodedFormBody!["last_name"] == "Doe")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).update(params: .init(firstName: "John", lastName: "Doe"), sessionId: sessionId)
    #expect(requestHandled.value)
  }

  @Test
  func updateWithUnsafeMetadataObjectEncodesMetadataAsJSONString() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me")

    try registerIsolatedStub(
      url: originalURL,
      method: .patch,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<User>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.allHTTPHeaderFields?["Content-Type"] == "application/x-www-form-urlencoded")
      #expect(request.urlEncodedFormBody!["unsafe_metadata"] == "{\"token\":\"some-value\"}")
      #expect(request.urlEncodedFormBody!["unsafe_metadata[token]"] == nil)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    let metadata: JSON = ["token": "some-value"]
    _ = try await makeService(baseURL: baseURL).update(params: .init(unsafeMetadata: metadata), sessionId: sessionId)
    #expect(requestHandled.value)
  }

  @Test
  func testGetSessions() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/sessions/active")

    try registerIsolatedStub(
      url: originalURL,
      method: .get,
      data: JSONEncoder.clerkEncoder.encode([Session.mock])
    ) { request in
      #expect(request.httpMethod == "GET")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).getSessions(sessionId: sessionId)
    #expect(requestHandled.value)
  }

  @Test
  func testUpdatePassword() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/change_password")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<User>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["new_password"] == "newPassword123")
      #expect(request.urlEncodedFormBody!["sign_out_of_other_sessions"] == "1")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).updatePassword(
      params: .init(newPassword: "newPassword123", signOutOfOtherSessions: true),
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func testSetProfileImage() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/profile_image")
    let imageData = Data("fake image data".utf8)

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(
        ClientResponse<ImageResource>(
          response: ImageResource(id: "1", name: "profile", publicUrl: "https://example.com/image.jpg"),
          client: .mock
        )
      )
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.allHTTPHeaderFields?["Content-Type"]?.contains("multipart/form-data") == true)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).setProfileImage(imageData: imageData, sessionId: sessionId)
    #expect(requestHandled.value)
  }

  @Test
  func testDeleteProfileImage() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/profile_image")

    try registerIsolatedStub(
      url: originalURL,
      method: .delete,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).deleteProfileImage(sessionId: sessionId)
    #expect(requestHandled.value)
  }

  @Test
  func testDelete() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me")

    try registerIsolatedStub(
      url: originalURL,
      method: .delete,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>(response: .mock, client: nil))
    ) { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).delete(sessionId: sessionId)
    #expect(requestHandled.value)
  }
}
