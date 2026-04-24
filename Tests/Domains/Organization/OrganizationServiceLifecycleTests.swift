@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.networking, .unit))
struct OrganizationServiceLifecycleTests {
  private let sessionId = "session_test_123"

  private func makeService(baseURL: URL) -> OrganizationService {
    OrganizationService(apiClient: createIsolatedMockAPIClient(baseURL: baseURL, protocolClass: IsolatedMockURLProtocol.self))
  }

  @Test
  func createOrganization() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/organizations")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<Organization>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.url?.query?.contains("_clerk_session_id=\(sessionId)") == true)
      #expect(request.urlEncodedFormBody!["name"] == "My Org")
      #expect(request.urlEncodedFormBody!["slug"] == nil)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).createOrganization(name: "My Org", slug: nil, sessionId: sessionId)
    #expect(requestHandled.value)
  }

  @Test
  func createOrganizationIncludesSlugWhenProvided() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/organizations")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<Organization>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.url?.query?.contains("_clerk_session_id=\(sessionId)") == true)
      #expect(request.urlEncodedFormBody!["name"] == "My Org")
      #expect(request.urlEncodedFormBody!["slug"] == "my-org")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).createOrganization(name: "My Org", slug: "my-org", sessionId: sessionId)
    #expect(requestHandled.value)
  }

  @Test
  func updateOrganization() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/organizations/\(organization.id)")

    try registerIsolatedStub(
      url: originalURL,
      method: .patch,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<Organization>(response: organization, client: .mock))
    ) { request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.url?.query?.contains("_clerk_session_id=\(sessionId)") == true)
      #expect(request.urlEncodedFormBody!["name"] == "New Name")
      #expect(request.urlEncodedFormBody!["slug"] == "new-slug")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).updateOrganization(
      organizationId: organization.id,
      name: "New Name",
      slug: "new-slug",
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func destroyOrganization() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/organizations/\(organization.id)")

    try registerIsolatedStub(
      url: originalURL,
      method: .delete,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "DELETE")
      #expect(request.url?.query?.contains("_clerk_session_id=\(sessionId)") == true)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).destroyOrganization(organizationId: organization.id, sessionId: sessionId)
    #expect(requestHandled.value)
  }

  @Test
  func setOrganizationLogo() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/organizations/\(organization.id)/logo")
    let imageData = Data("fake image data".utf8)

    try registerIsolatedStub(
      url: originalURL,
      method: .put,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<Organization>(response: organization, client: .mock))
    ) { request in
      #expect(request.httpMethod == "PUT")
      #expect(request.url?.query?.contains("_clerk_session_id=\(sessionId)") == true)
      #expect(request.allHTTPHeaderFields?["Content-Type"]?.contains("multipart/form-data") == true)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).setOrganizationLogo(
      organizationId: organization.id,
      imageData: imageData,
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationRoles() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/organizations/\(organization.id)/roles")

    try registerIsolatedStub(
      url: originalURL,
      method: .get,
      data: JSONEncoder.clerkEncoder.encode(
        ClientResponse<ClerkPaginatedResponse<RoleResource>>(
          response: ClerkPaginatedResponse(data: [.mock], totalCount: 1),
          client: .mock
        )
      )
    ) { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("_clerk_session_id=\(sessionId)") == true)
      #expect(request.url?.query?.contains("offset=0") == true)
      #expect(request.url?.query?.contains("limit=10") == true)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).getOrganizationRoles(
      organizationId: organization.id,
      offset: 0,
      pageSize: 10,
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }
}
