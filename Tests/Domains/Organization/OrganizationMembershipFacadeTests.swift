@testable import ClerkKit
import ConcurrencyExtras
import Testing

@MainActor
@Suite(.tags(.unit))
struct OrganizationMembershipFacadeTests {
  private let support = OrganizationTestSupport()

  @Test(
    arguments: [
      OrganizationMembershipsScenario(query: nil, role: nil),
      OrganizationMembershipsScenario(query: "test", role: nil),
      OrganizationMembershipsScenario(query: nil, role: ["admin"]),
    ]
  )
  func getOrganizationMembershipsUsesOrganizationServiceGetOrganizationMemberships(
    scenario: OrganizationMembershipsScenario
  ) async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, String?, [String]?, Int, Int)?>(nil)
    let service = MockOrganizationService(getOrganizationMemberships: { organizationId, query, role, offset, pageSize, _ in
      captured.setValue((organizationId, query, role, offset, pageSize))
      return ClerkPaginatedResponse(data: [.mockWithUserData], totalCount: 1)
    })
    let clerk = try support.makeClerk(organizationService: service)

    _ = try await clerk.organizations.getMemberships(
      for: organization,
      query: scenario.query,
      role: scenario.role,
      page: 3,
      pageSize: 10
    )

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == scenario.query)
    #expect(params.2 == scenario.role)
    #expect(params.3 == 20)
    #expect(params.4 == 10)
  }

  @Test
  func addOrganizationMemberUsesOrganizationServiceAddOrganizationMember() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, String, String)?>(nil)
    let service = MockOrganizationService(addOrganizationMember: { organizationId, userId, role, _ in
      captured.setValue((organizationId, userId, role))
      return .mockWithUserData
    })
    let clerk = try support.makeClerk(organizationService: service)

    _ = try await clerk.organizations.addMember(
      to: organization,
      userId: "user123",
      role: "org:member"
    )

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == "user123")
    #expect(params.2 == "org:member")
  }

  @Test
  func updateOrganizationMemberUsesOrganizationServiceUpdateOrganizationMember() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, String, String)?>(nil)
    let service = MockOrganizationService(updateOrganizationMember: { organizationId, forwardedUserId, role, _ in
      captured.setValue((organizationId, forwardedUserId, role))
      return .mockWithUserData
    })
    let clerk = try support.makeClerk(organizationService: service)

    _ = try await clerk.organizations.updateMember(
      in: organization,
      userId: "user123",
      role: "org:admin"
    )

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == "user123")
    #expect(params.2 == "org:admin")
  }

  @Test
  func removeOrganizationMemberUsesOrganizationServiceRemoveOrganizationMember() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, String)?>(nil)
    let service = MockOrganizationService(removeOrganizationMember: { organizationId, userId, _ in
      captured.setValue((organizationId, userId))
      return .mockWithUserData
    })
    let clerk = try support.makeClerk(organizationService: service)

    _ = try await clerk.organizations.removeMember(from: organization, userId: "user123")

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == "user123")
  }

  @Test
  func updateOrganizationMembershipUsesOrganizationServiceUpdateOrganizationMember() async throws {
    let membership = OrganizationMembership.mockWithUserData
    let userId = try #require(membership.publicUserData?.userId)
    let captured = LockIsolated<(String, String, String)?>(nil)
    let service = MockOrganizationService(updateOrganizationMember: { organizationId, userId, role, _ in
      captured.setValue((organizationId, userId, role))
      return .mockWithUserData
    })
    let clerk = try support.makeClerk(organizationService: service)

    _ = try await clerk.organizations.update(membership, role: "org:admin")

    let params = try #require(captured.value)
    #expect(params.0 == membership.organization.id)
    #expect(params.1 == userId)
    #expect(params.2 == "org:admin")
  }

  @Test
  func destroyOrganizationMembershipUsesOrganizationServiceDestroyOrganizationMembership() async throws {
    let membership = OrganizationMembership.mockWithUserData
    let userId = try #require(membership.publicUserData?.userId)
    let captured = LockIsolated<(String, String)?>(nil)
    let service = MockOrganizationService(destroyOrganizationMembership: { organizationId, forwardedUserId in
      captured.setValue((organizationId, forwardedUserId))
      return .mockWithUserData
    })
    let clerk = try support.makeClerk(organizationService: service)

    _ = try await clerk.organizations.destroy(membership)

    let params = try #require(captured.value)
    #expect(params.0 == membership.organization.id)
    #expect(params.1 == userId)
  }
}
