import ConcurrencyExtras
import Foundation
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct OrganizationTests {
  init() {
    Clerk.configure(publishableKey: testPublishableKey)
  }

  private func configureOrganizationService(_ service: MockOrganizationService) {
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      organizationService: service
    )
  }

  @Test
  func updateOrganizationUsesService() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, String, String?)?>(nil)
    let service = MockOrganizationService(updateOrganization: { id, name, slug in
      captured.setValue((id, name, slug))
      return .mock
    })

    configureOrganizationService(service)

    _ = try await organization.update(name: "New Name", slug: "new-slug")

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == "New Name")
    #expect(params.2 == "new-slug")
  }

  @Test
  func destroyOrganizationUsesService() async throws {
    let organization = Organization.mock
    let capturedId = LockIsolated<String?>(nil)
    let service = MockOrganizationService(destroyOrganization: { organizationId in
      capturedId.setValue(organizationId)
      return .mock
    })

    configureOrganizationService(service)

    _ = try await organization.destroy()

    #expect(capturedId.value == organization.id)
  }

  @Test
  func setOrganizationLogoUsesService() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, Data)?>(nil)
    let service = MockOrganizationService(setOrganizationLogo: { organizationId, imageData in
      captured.setValue((organizationId, imageData))
      return .mock
    })

    configureOrganizationService(service)

    let imageData = Data("fake image data".utf8)
    _ = try await organization.setLogo(imageData: imageData)

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == imageData)
  }

  @Test
  func getOrganizationRolesUsesService() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, Int, Int)?>(nil)
    let service = MockOrganizationService(getOrganizationRoles: { organizationId, initialPage, pageSize in
      captured.setValue((organizationId, initialPage, pageSize))
      return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
    })

    configureOrganizationService(service)

    _ = try await organization.getRoles(initialPage: 0, pageSize: 10)

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == 0)
    #expect(params.2 == 10)
  }

  @Test
  func getOrganizationMembershipsUsesService() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, String?, [String]?, Int, Int)?>(nil)
    let service = MockOrganizationService(getOrganizationMemberships: { organizationId, query, role, initialPage, pageSize in
      captured.setValue((organizationId, query, role, initialPage, pageSize))
      return ClerkPaginatedResponse(data: [.mockWithUserData], totalCount: 1)
    })

    configureOrganizationService(service)

    _ = try await organization.getMemberships(initialPage: 0, pageSize: 10)

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == nil)
    #expect(params.2 == nil)
    #expect(params.3 == 0)
    #expect(params.4 == 10)
  }

  @Test
  func getOrganizationMembershipsWithQueryUsesService() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, String?, [String]?, Int, Int)?>(nil)
    let service = MockOrganizationService(getOrganizationMemberships: { organizationId, query, role, initialPage, pageSize in
      captured.setValue((organizationId, query, role, initialPage, pageSize))
      return ClerkPaginatedResponse(data: [.mockWithUserData], totalCount: 1)
    })

    configureOrganizationService(service)

    _ = try await organization.getMemberships(query: "test", initialPage: 0, pageSize: 10)

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == "test")
    #expect(params.2 == nil)
    #expect(params.3 == 0)
    #expect(params.4 == 10)
  }

  @Test
  func getOrganizationMembershipsWithRoleUsesService() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, String?, [String]?, Int, Int)?>(nil)
    let service = MockOrganizationService(getOrganizationMemberships: { organizationId, query, role, initialPage, pageSize in
      captured.setValue((organizationId, query, role, initialPage, pageSize))
      return ClerkPaginatedResponse(data: [.mockWithUserData], totalCount: 1)
    })

    configureOrganizationService(service)

    _ = try await organization.getMemberships(role: ["admin"], initialPage: 0, pageSize: 10)

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == nil)
    #expect(params.2 == ["admin"])
    #expect(params.3 == 0)
    #expect(params.4 == 10)
  }

  @Test
  func addOrganizationMemberUsesService() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, String, String)?>(nil)
    let service = MockOrganizationService(addOrganizationMember: { organizationId, userId, role in
      captured.setValue((organizationId, userId, role))
      return .mockWithUserData
    })

    configureOrganizationService(service)

    _ = try await organization.addMember(userId: "user123", role: "org:member")

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == "user123")
    #expect(params.2 == "org:member")
  }

  @Test
  func updateOrganizationMemberUsesService() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, String, String)?>(nil)
    let service = MockOrganizationService(updateOrganizationMember: { organizationId, userId, role in
      captured.setValue((organizationId, userId, role))
      return .mockWithUserData
    })

    configureOrganizationService(service)

    _ = try await organization.updateMember(userId: "user123", role: "org:admin")

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == "user123")
    #expect(params.2 == "org:admin")
  }

  @Test
  func removeOrganizationMemberUsesService() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, String)?>(nil)
    let service = MockOrganizationService(removeOrganizationMember: { organizationId, userId in
      captured.setValue((organizationId, userId))
      return .mockWithUserData
    })

    configureOrganizationService(service)

    _ = try await organization.removeMember(userId: "user123")

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == "user123")
  }

  @Test
  func updateOrganizationMembershipUsesService() async throws {
    let membership = OrganizationMembership.mockWithUserData
    let captured = LockIsolated<(String, String, String)?>(nil)
    let service = MockOrganizationService(updateOrganizationMember: { organizationId, userId, role in
      captured.setValue((organizationId, userId, role))
      return .mockWithUserData
    })

    configureOrganizationService(service)

    _ = try await membership.update(role: "org:admin")

    let params = try #require(captured.value)
    #expect(params.0 == membership.organization.id)
    #expect(params.1 == membership.publicUserData?.userId)
    #expect(params.2 == "org:admin")
  }

  @Test
  func destroyOrganizationMembershipUsesService() async throws {
    let membership = OrganizationMembership.mockWithUserData
    let captured = LockIsolated<(String, String)?>(nil)
    let service = MockOrganizationService(destroyOrganizationMembership: { organizationId, userId in
      captured.setValue((organizationId, userId))
      return .mockWithUserData
    })

    configureOrganizationService(service)

    _ = try await membership.destroy()

    let params = try #require(captured.value)
    #expect(params.0 == membership.organization.id)
    #expect(params.1 == membership.publicUserData?.userId)
  }

  @Test
  func getOrganizationInvitationsUsesService() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, Int, Int, String?)?>(nil)
    let service = MockOrganizationService(getOrganizationInvitations: { organizationId, initialPage, pageSize, status in
      captured.setValue((organizationId, initialPage, pageSize, status))
      return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
    })

    configureOrganizationService(service)

    _ = try await organization.getInvitations(initialPage: 0, pageSize: 10)

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == 0)
    #expect(params.2 == 10)
    #expect(params.3 == nil)
  }

  @Test
  func getOrganizationInvitationsWithStatusUsesService() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, Int, Int, String?)?>(nil)
    let service = MockOrganizationService(getOrganizationInvitations: { organizationId, initialPage, pageSize, status in
      captured.setValue((organizationId, initialPage, pageSize, status))
      return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
    })

    configureOrganizationService(service)

    _ = try await organization.getInvitations(initialPage: 0, pageSize: 10, status: "pending")

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == 0)
    #expect(params.2 == 10)
    #expect(params.3 == "pending")
  }

  @Test
  func inviteOrganizationMemberUsesService() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, String, String)?>(nil)
    let service = MockOrganizationService(inviteOrganizationMember: { organizationId, emailAddress, role in
      captured.setValue((organizationId, emailAddress, role))
      return .mock
    })

    configureOrganizationService(service)

    _ = try await organization.inviteMember(emailAddress: "user@example.com", role: "org:member")

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == "user@example.com")
    #expect(params.2 == "org:member")
  }

  @Test
  func createOrganizationDomainUsesService() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, String)?>(nil)
    let service = MockOrganizationService(createOrganizationDomain: { organizationId, domainName in
      captured.setValue((organizationId, domainName))
      return .mock
    })

    configureOrganizationService(service)

    _ = try await organization.createDomain(domainName: "example.com")

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == "example.com")
  }

  @Test
  func getOrganizationDomainsUsesService() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, Int, Int, String?)?>(nil)
    let service = MockOrganizationService(getOrganizationDomains: { organizationId, initialPage, pageSize, enrollmentMode in
      captured.setValue((organizationId, initialPage, pageSize, enrollmentMode))
      return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
    })

    configureOrganizationService(service)

    _ = try await organization.getDomains(initialPage: 0, pageSize: 10)

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == 0)
    #expect(params.2 == 10)
    #expect(params.3 == nil)
  }

  @Test
  func getOrganizationDomainsWithEnrollmentModeUsesService() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, Int, Int, String?)?>(nil)
    let service = MockOrganizationService(getOrganizationDomains: { organizationId, initialPage, pageSize, enrollmentMode in
      captured.setValue((organizationId, initialPage, pageSize, enrollmentMode))
      return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
    })

    configureOrganizationService(service)

    _ = try await organization.getDomains(initialPage: 0, pageSize: 10, enrollmentMode: "automatic")

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == 0)
    #expect(params.2 == 10)
    #expect(params.3 == "automatic")
  }

  @Test
  func getOrganizationDomainUsesService() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, String)?>(nil)
    let service = MockOrganizationService(getOrganizationDomain: { organizationId, domainId in
      captured.setValue((organizationId, domainId))
      return .mock
    })

    configureOrganizationService(service)

    _ = try await organization.getDomain(domainId: "domain123")

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == "domain123")
  }

  @Test
  func getOrganizationMembershipRequestsUsesService() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, Int, Int, String?)?>(nil)
    let service = MockOrganizationService(getOrganizationMembershipRequests: { organizationId, initialPage, pageSize, status in
      captured.setValue((organizationId, initialPage, pageSize, status))
      return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
    })

    configureOrganizationService(service)

    _ = try await organization.getMembershipRequests(initialPage: 0, pageSize: 10)

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == 0)
    #expect(params.2 == 10)
    #expect(params.3 == nil)
  }

  @Test
  func getOrganizationMembershipRequestsWithStatusUsesService() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, Int, Int, String?)?>(nil)
    let service = MockOrganizationService(getOrganizationMembershipRequests: { organizationId, initialPage, pageSize, status in
      captured.setValue((organizationId, initialPage, pageSize, status))
      return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
    })

    configureOrganizationService(service)

    _ = try await organization.getMembershipRequests(initialPage: 0, pageSize: 10, status: "pending")

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == 0)
    #expect(params.2 == 10)
    #expect(params.3 == "pending")
  }

  @Test
  func deleteOrganizationDomainUsesService() async throws {
    let domain = OrganizationDomain.mock
    let captured = LockIsolated<(String, String)?>(nil)
    let service = MockOrganizationService(deleteOrganizationDomain: { organizationId, domainId in
      captured.setValue((organizationId, domainId))
      return .mock
    })

    configureOrganizationService(service)

    _ = try await domain.delete()

    let params = try #require(captured.value)
    #expect(params.0 == domain.organizationId)
    #expect(params.1 == domain.id)
  }

  @Test
  func prepareOrganizationDomainAffiliationVerificationUsesService() async throws {
    let domain = OrganizationDomain.mock
    let captured = LockIsolated<(String, String, String)?>(nil)
    let service = MockOrganizationService(prepareOrganizationDomainAffiliationVerification: { organizationId, domainId, emailAddress in
      captured.setValue((organizationId, domainId, emailAddress))
      return .mock
    })

    configureOrganizationService(service)

    _ = try await domain.prepareAffiliationVerification(affiliationEmailAddress: "user@example.com")

    let params = try #require(captured.value)
    #expect(params.0 == domain.organizationId)
    #expect(params.1 == domain.id)
    #expect(params.2 == "user@example.com")
  }

  @Test
  func attemptOrganizationDomainAffiliationVerificationUsesService() async throws {
    let domain = OrganizationDomain.mock
    let captured = LockIsolated<(String, String, String)?>(nil)
    let service = MockOrganizationService(attemptOrganizationDomainAffiliationVerification: { organizationId, domainId, code in
      captured.setValue((organizationId, domainId, code))
      return .mock
    })

    configureOrganizationService(service)

    _ = try await domain.attemptAffiliationVerification(code: "123456")

    let params = try #require(captured.value)
    #expect(params.0 == domain.organizationId)
    #expect(params.1 == domain.id)
    #expect(params.2 == "123456")
  }

  @Test
  func revokeOrganizationInvitationUsesService() async throws {
    let invitation = OrganizationInvitation.mock
    let captured = LockIsolated<(String, String)?>(nil)
    let service = MockOrganizationService(revokeOrganizationInvitation: { organizationId, invitationId in
      captured.setValue((organizationId, invitationId))
      return .mock
    })

    configureOrganizationService(service)

    _ = try await invitation.revoke()

    let params = try #require(captured.value)
    #expect(params.0 == invitation.organizationId)
    #expect(params.1 == invitation.id)
  }

  @Test
  func acceptUserOrganizationInvitationUsesService() async throws {
    let invitation = UserOrganizationInvitation.mock
    let captured = LockIsolated<String?>(nil)
    let service = MockOrganizationService(acceptUserOrganizationInvitation: { invitationId in
      captured.setValue(invitationId)
      return .mock
    })

    configureOrganizationService(service)

    _ = try await invitation.accept()

    #expect(captured.value == invitation.id)
  }

  @Test
  func acceptOrganizationSuggestionUsesService() async throws {
    let suggestion = OrganizationSuggestion.mock
    let captured = LockIsolated<String?>(nil)
    let service = MockOrganizationService(acceptOrganizationSuggestion: { suggestionId in
      captured.setValue(suggestionId)
      return .mock
    })

    configureOrganizationService(service)

    _ = try await suggestion.accept()

    #expect(captured.value == suggestion.id)
  }

  @Test
  func acceptOrganizationMembershipRequestUsesService() async throws {
    let request = OrganizationMembershipRequest.mock
    let captured = LockIsolated<(String, String)?>(nil)
    let service = MockOrganizationService(acceptOrganizationMembershipRequest: { organizationId, requestId in
      captured.setValue((organizationId, requestId))
      return .mock
    })

    configureOrganizationService(service)

    _ = try await request.accept()

    let params = try #require(captured.value)
    #expect(params.0 == request.organizationId)
    #expect(params.1 == request.id)
  }

  @Test
  func rejectOrganizationMembershipRequestUsesService() async throws {
    let request = OrganizationMembershipRequest.mock
    let captured = LockIsolated<(String, String)?>(nil)
    let service = MockOrganizationService(rejectOrganizationMembershipRequest: { organizationId, requestId in
      captured.setValue((organizationId, requestId))
      return .mock
    })

    configureOrganizationService(service)

    _ = try await request.reject()

    let params = try #require(captured.value)
    #expect(params.0 == request.organizationId)
    #expect(params.1 == request.id)
  }
}
