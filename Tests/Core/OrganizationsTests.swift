@testable import ClerkKit
import ConcurrencyExtras
import Testing

@MainActor
@Suite(.tags(.unit))
struct OrganizationsTests {
  @Test
  func createUsesOrganizationServiceCreateOrganization() async throws {
    let captured = LockIsolated<(String, String?)?>(nil)
    let service = MockOrganizationService(createOrganization: { name, slug in
      captured.setValue((name, slug))
      return .mock
    })
    let clerk = Clerk()

    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      organizationService: service
    )

    _ = try await clerk.organizations.create(name: "My Org", slug: nil)

    let params = try #require(captured.value)
    #expect(params.0 == "My Org")
    #expect(params.1 == nil)
  }
}
