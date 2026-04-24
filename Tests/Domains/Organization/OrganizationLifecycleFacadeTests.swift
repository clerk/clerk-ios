@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.unit))
struct OrganizationLifecycleFacadeTests {
  private let support = OrganizationTestSupport()

  @Test
  func updateOrganizationUsesOrganizationServiceUpdateOrganization() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, String, String?)?>(nil)
    let service = MockOrganizationService(updateOrganization: { id, name, slug, _ in
      captured.setValue((id, name, slug))
      return .mock
    })
    let clerk = try support.makeClerk(organizationService: service)

    _ = try await clerk.organizations.update(organization, name: "New Name", slug: "new-slug")

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == "New Name")
    #expect(params.2 == "new-slug")
  }

  @Test
  func destroyOrganizationUsesOrganizationServiceDestroyOrganization() async throws {
    let organization = Organization.mock
    let capturedId = LockIsolated<String?>(nil)
    let service = MockOrganizationService(destroyOrganization: { organizationId, _ in
      capturedId.setValue(organizationId)
      return .mock
    })
    let clerk = try support.makeClerk(organizationService: service)

    _ = try await clerk.organizations.destroy(organization)

    #expect(capturedId.value == organization.id)
  }

  @Test
  func setOrganizationLogoUsesOrganizationServiceSetOrganizationLogo() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, Data)?>(nil)
    let service = MockOrganizationService(setOrganizationLogo: { organizationId, imageData, _ in
      captured.setValue((organizationId, imageData))
      return .mock
    })
    let clerk = try support.makeClerk(organizationService: service)

    let imageData = Data("fake image data".utf8)
    _ = try await clerk.organizations.setLogo(for: organization, imageData: imageData)

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == imageData)
  }

  @Test
  func getOrganizationRolesUsesOrganizationServiceGetOrganizationRoles() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, Int, Int)?>(nil)
    let service = MockOrganizationService(getOrganizationRoles: { organizationId, offset, pageSize, _ in
      captured.setValue((organizationId, offset, pageSize))
      return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
    })
    let clerk = try support.makeClerk(organizationService: service)

    _ = try await clerk.organizations.getRoles(for: organization, page: 2, pageSize: 10)

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == 10)
    #expect(params.2 == 10)
  }
}
