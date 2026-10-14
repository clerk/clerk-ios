@testable import ClerkKit
import ConcurrencyExtras
import Testing

@MainActor
@Suite(.serialized)
struct OrganizationsTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func createSendsNameAndOmitsNilSlug() async throws {
    let captured = LockIsolated<JSON?>(nil)
    let transport = FakeTransport.mockDefaults()
    transport.stub(OrganizationAPI.create(name: "", slug: nil)) { call in
      captured.setValue(call.body)
      return ClientResponse(response: .mock, client: nil)
    }

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      transport: transport
    )

    _ = try await Clerk.shared.organizations.create(name: "My Org", slug: nil)

    let body = try #require(captured.value)
    #expect(body["name"]?.stringValue == "My Org")
    #expect(body["slug"] == nil)
  }

  @Test
  func getRequestsOrganizationById() async throws {
    let capturedPath = LockIsolated<String?>(nil)
    let transport = FakeTransport.mockDefaults()
    transport.stub(OrganizationAPI.get(organizationId: FakeTransport.anyPathSegment)) { call in
      capturedPath.setValue(call.path)
      return ClientResponse(response: .mock, client: nil)
    }

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      transport: transport
    )

    _ = try await Clerk.shared.organizations.get(id: "org_123")

    #expect(capturedPath.value == "/v1/organizations/org_123")
  }
}
