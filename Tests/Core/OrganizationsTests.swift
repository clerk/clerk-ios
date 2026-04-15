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
  func createUsesOrganizationServiceCreateOrganization() async throws {
    let captured = LockIsolated<(String, String?)?>(nil)
    let service = MockOrganizationService(createOrganization: { name, slug in
      captured.setValue((name, slug))
      return .mock
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      organizationService: service
    )

    _ = try await Clerk.shared.organizations.create(name: "My Org", slug: nil)

    let params = try #require(captured.value)
    #expect(params.0 == "My Org")
    #expect(params.1 == nil)
  }
}
