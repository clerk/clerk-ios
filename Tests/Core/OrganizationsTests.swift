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
    let capturedName = LockIsolated<String?>(nil)
    let service = MockOrganizationService(createOrganization: { name in
      capturedName.setValue(name)
      return .mock
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      organizationService: service
    )

    _ = try await Clerk.shared.organizations.create(name: "My Org")

    #expect(capturedName.value == "My Org")
  }
}
