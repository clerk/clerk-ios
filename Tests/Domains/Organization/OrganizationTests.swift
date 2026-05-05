@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct OrganizationTests {
  init() {
    configureClerkForTesting()
  }

  private func configureOrganizationService(_ service: MockOrganizationService) {
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      organizationService: service
    )
  }

  struct MembershipsScenario: Codable, Equatable {
    let query: String?
    let role: [String]?
  }

  struct InvitationsScenario: Codable, Equatable {
    let status: String?
  }

  struct DomainsScenario: Codable, Equatable {
    let enrollmentMode: String?
  }

  struct MembershipRequestsScenario: Codable, Equatable {
    let status: String?
  }

  @Test
  func updateOrganizationUsesOrganizationServiceUpdateOrganization() async throws {
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
  func destroyOrganizationUsesOrganizationServiceDestroyOrganization() async throws {
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
  func setOrganizationLogoUsesOrganizationServiceSetOrganizationLogo() async throws {
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
  func deleteOrganizationLogoUsesOrganizationServiceDeleteOrganizationLogo() async throws {
    let organization = Organization.mock
    let capturedId = LockIsolated<String?>(nil)
    let service = MockOrganizationService(deleteOrganizationLogo: { organizationId in
      capturedId.setValue(organizationId)
      return .mock
    })

    configureOrganizationService(service)

    _ = try await organization.deleteLogo()

    #expect(capturedId.value == organization.id)
  }

  @Test
  func getOrganizationRolesUsesOrganizationServiceGetOrganizationRoles() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, Int, Int)?>(nil)
    let service = MockOrganizationService(getOrganizationRoles: { organizationId, initialPage, pageSize in
      captured.setValue((organizationId, initialPage, pageSize))
      return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
    })

    configureOrganizationService(service)

    _ = try await organization.getRoles(page: 2, pageSize: 10)

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == 10)
    #expect(params.2 == 10)
  }

  @Test(
    arguments: [
      MembershipsScenario(query: nil, role: nil),
      MembershipsScenario(query: "test", role: nil),
      MembershipsScenario(query: nil, role: ["admin"]),
    ]
  )
  func getOrganizationMembershipsUsesOrganizationServiceGetOrganizationMemberships(
    scenario: MembershipsScenario
  ) async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, String?, [String]?, Int, Int)?>(nil)
    let service = MockOrganizationService(getOrganizationMemberships: { organizationId, query, role, initialPage, pageSize in
      captured.setValue((organizationId, query, role, initialPage, pageSize))
      return ClerkPaginatedResponse(data: [.mockWithUserData], totalCount: 1)
    })

    configureOrganizationService(service)

    _ = try await organization.getMemberships(
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
  func getOrganizationMembershipsWithOffsetUsesOrganizationServiceGetOrganizationMemberships() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, String?, [String]?, Int, Int)?>(nil)
    let service = MockOrganizationService(getOrganizationMemberships: { organizationId, query, role, initialPage, pageSize in
      captured.setValue((organizationId, query, role, initialPage, pageSize))
      return ClerkPaginatedResponse(data: [.mockWithUserData], totalCount: 1)
    })

    configureOrganizationService(service)

    _ = try await organization.getMemberships(
      query: "search",
      role: ["admin"],
      offset: 30,
      pageSize: 10
    )

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == "search")
    #expect(params.2 == ["admin"])
    #expect(params.3 == 30)
    #expect(params.4 == 10)
  }

  @Test
  func addOrganizationMemberUsesOrganizationServiceAddOrganizationMember() async throws {
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
  func updateOrganizationMemberUsesOrganizationServiceUpdateOrganizationMember() async throws {
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
  func removeOrganizationMemberUsesOrganizationServiceRemoveOrganizationMember() async throws {
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
  func updateOrganizationMembershipUsesOrganizationServiceUpdateOrganizationMember() async throws {
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
  func destroyOrganizationMembershipUsesOrganizationServiceDestroyOrganizationMembership() async throws {
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
  func organizationMembershipPermissionHelpers() {
    var membership = OrganizationMembership.mockWithUserData
    membership.permissions = [
      OrganizationSystemPermission.manageProfile.rawValue,
      OrganizationSystemPermission.deleteProfile.rawValue,
      OrganizationSystemPermission.readMemberships.rawValue,
      OrganizationSystemPermission.manageDomains.rawValue,
      OrganizationSystemPermission.manageBilling.rawValue,
      "org:custom:permission",
    ]

    #expect(membership.hasPermission(.manageProfile))
    #expect(membership.hasPermission("org:custom:permission"))
    #expect(membership.canManageProfile)
    #expect(membership.canDeleteOrganization)
    #expect(membership.canReadMemberships)
    #expect(membership.canManageDomains)
    #expect(membership.canManageBilling)
    #expect(membership.canManageMemberships == false)
    #expect(membership.canReadDomains == false)
    #expect(membership.canReadBilling == false)
    #expect(membership.canReadAPIKeys == false)
    #expect(membership.canManageAPIKeys == false)

    membership.permissions = nil

    #expect(membership.hasPermission(.manageProfile) == false)
  }

  @Test(
    arguments: [
      InvitationsScenario(status: nil),
      InvitationsScenario(status: "pending"),
    ]
  )
  func getOrganizationInvitationsUsesOrganizationServiceGetOrganizationInvitations(
    scenario: InvitationsScenario
  ) async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, Int, Int, String?)?>(nil)
    let service = MockOrganizationService(getOrganizationInvitations: { organizationId, initialPage, pageSize, status in
      captured.setValue((organizationId, initialPage, pageSize, status))
      return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
    })

    configureOrganizationService(service)

    _ = try await organization.getInvitations(
      page: 2,
      pageSize: 10,
      status: scenario.status
    )

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == 10)
    #expect(params.2 == 10)
    #expect(params.3 == scenario.status)
  }

  @Test
  func getOrganizationInvitationsWithOffsetUsesOrganizationServiceGetOrganizationInvitations() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, Int, Int, String?)?>(nil)
    let service = MockOrganizationService(getOrganizationInvitations: { organizationId, initialPage, pageSize, status in
      captured.setValue((organizationId, initialPage, pageSize, status))
      return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
    })

    configureOrganizationService(service)

    _ = try await organization.getInvitations(
      offset: 30,
      pageSize: 10,
      status: "pending"
    )

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == 30)
    #expect(params.2 == 10)
    #expect(params.3 == "pending")
  }

  @Test
  func inviteOrganizationMemberUsesOrganizationServiceInviteOrganizationMember() async throws {
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
  func inviteOrganizationMembersUsesOrganizationServiceInviteOrganizationMembers() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, [String], String)?>(nil)
    let service = MockOrganizationService(inviteOrganizationMembers: { organizationId, emailAddresses, role in
      captured.setValue((organizationId, emailAddresses, role))
      return [.mock]
    })

    configureOrganizationService(service)

    _ = try await organization.inviteMembers(
      emailAddresses: ["one@example.com", "two@example.com"],
      role: "org:member"
    )

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == ["one@example.com", "two@example.com"])
    #expect(params.2 == "org:member")
  }

  @Test
  func createOrganizationDomainUsesOrganizationServiceCreateOrganizationDomain() async throws {
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

  @Test(
    arguments: [
      DomainsScenario(enrollmentMode: nil),
      DomainsScenario(enrollmentMode: "automatic"),
    ]
  )
  func getOrganizationDomainsUsesOrganizationServiceGetOrganizationDomains(
    scenario: DomainsScenario
  ) async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, Int, Int, String?)?>(nil)
    let service = MockOrganizationService(getOrganizationDomains: { organizationId, initialPage, pageSize, enrollmentMode in
      captured.setValue((organizationId, initialPage, pageSize, enrollmentMode))
      return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
    })

    configureOrganizationService(service)

    _ = try await organization.getDomains(
      page: 2,
      pageSize: 10,
      enrollmentMode: scenario.enrollmentMode
    )

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == 10)
    #expect(params.2 == 10)
    #expect(params.3 == scenario.enrollmentMode)
  }

  @Test
  func getOrganizationDomainsWithTypedEnrollmentModeUsesRawEnrollmentMode() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, Int, Int, String?)?>(nil)
    let service = MockOrganizationService(getOrganizationDomains: { organizationId, initialPage, pageSize, enrollmentMode in
      captured.setValue((organizationId, initialPage, pageSize, enrollmentMode))
      return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
    })

    configureOrganizationService(service)

    _ = try await organization.getDomains(
      page: 2,
      pageSize: 10,
      enrollmentMode: .automaticInvitation
    )

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == 10)
    #expect(params.2 == 10)
    #expect(params.3 == OrganizationDomain.EnrollmentMode.automaticInvitation.rawValue)
  }

  @Test
  func getOrganizationDomainsWithOffsetUsesOrganizationServiceGetOrganizationDomains() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, Int, Int, String?)?>(nil)
    let service = MockOrganizationService(getOrganizationDomains: { organizationId, initialPage, pageSize, enrollmentMode in
      captured.setValue((organizationId, initialPage, pageSize, enrollmentMode))
      return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
    })

    configureOrganizationService(service)

    _ = try await organization.getDomains(
      offset: 20,
      pageSize: 10,
      enrollmentMode: OrganizationDomain.EnrollmentMode.automaticSuggestion.rawValue
    )

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == 20)
    #expect(params.2 == 10)
    #expect(params.3 == OrganizationDomain.EnrollmentMode.automaticSuggestion.rawValue)
  }

  @Test
  func getOrganizationDomainUsesOrganizationServiceGetOrganizationDomain() async throws {
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

  @Test(
    arguments: [
      MembershipRequestsScenario(status: nil),
      MembershipRequestsScenario(status: "pending"),
    ]
  )
  func getOrganizationMembershipRequestsUsesOrganizationServiceGetOrganizationMembershipRequests(
    scenario: MembershipRequestsScenario
  ) async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, Int, Int, String?)?>(nil)
    let service = MockOrganizationService(getOrganizationMembershipRequests: { organizationId, initialPage, pageSize, status in
      captured.setValue((organizationId, initialPage, pageSize, status))
      return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
    })

    configureOrganizationService(service)

    _ = try await organization.getMembershipRequests(
      page: 2,
      pageSize: 10,
      status: scenario.status
    )

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == 10)
    #expect(params.2 == 10)
    #expect(params.3 == scenario.status)
  }

  @Test
  func getOrganizationMembershipRequestsWithOffsetUsesOrganizationServiceGetOrganizationMembershipRequests() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, Int, Int, String?)?>(nil)
    let service = MockOrganizationService(getOrganizationMembershipRequests: { organizationId, initialPage, pageSize, status in
      captured.setValue((organizationId, initialPage, pageSize, status))
      return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
    })

    configureOrganizationService(service)

    _ = try await organization.getMembershipRequests(
      offset: 30,
      pageSize: 10,
      status: "pending"
    )

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == 30)
    #expect(params.2 == 10)
    #expect(params.3 == "pending")
  }

  @Test
  func deleteOrganizationDomainUsesOrganizationServiceDeleteOrganizationDomain() async throws {
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
  func sendEmailCodeUsesOrganizationServicePrepareOrganizationDomainAffiliationVerification() async throws {
    let domain = OrganizationDomain.mock
    let captured = LockIsolated<(String, String, String)?>(nil)
    let service = MockOrganizationService(prepareOrganizationDomainAffiliationVerification: { organizationId, domainId, emailAddress in
      captured.setValue((organizationId, domainId, emailAddress))
      return .mock
    })

    configureOrganizationService(service)

    _ = try await domain.sendEmailCode(affiliationEmailAddress: "user@example.com")

    let params = try #require(captured.value)
    #expect(params.0 == domain.organizationId)
    #expect(params.1 == domain.id)
    #expect(params.2 == "user@example.com")
  }

  @Test
  func verifyCodeUsesOrganizationServiceAttemptOrganizationDomainAffiliationVerification() async throws {
    let domain = OrganizationDomain.mock
    let captured = LockIsolated<(String, String, String)?>(nil)
    let service = MockOrganizationService(attemptOrganizationDomainAffiliationVerification: { organizationId, domainId, code in
      captured.setValue((organizationId, domainId, code))
      return .mock
    })

    configureOrganizationService(service)

    _ = try await domain.verifyCode("123456")

    let params = try #require(captured.value)
    #expect(params.0 == domain.organizationId)
    #expect(params.1 == domain.id)
    #expect(params.2 == "123456")
  }

  @Test
  func organizationDomainEnrollmentModeTypeUsesTypedMode() {
    var domain = OrganizationDomain.mock
    domain.enrollmentMode = OrganizationDomain.EnrollmentMode.automaticInvitation.rawValue

    #expect(domain.enrollmentModeType == .automaticInvitation)

    domain.enrollmentMode = "future_mode"

    #expect(domain.enrollmentModeType == .unknown("future_mode"))
  }

  @Test
  func organizationDomainIsVerifiedUsesVerificationStatus() {
    var domain = OrganizationDomain.mock
    domain.verification.status = "verified"

    #expect(domain.isVerified)

    domain.verification.status = "unverified"

    #expect(!domain.isVerified)
  }

  @Test
  func updateOrganizationDomainEnrollmentModeUsesOrganizationServiceUpdateOrganizationDomainEnrollmentMode() async throws {
    let domain = OrganizationDomain.mock
    let captured = LockIsolated<(String, String, String, Bool?)?>(nil)
    let service = MockOrganizationService(updateOrganizationDomainEnrollmentMode: { organizationId, domainId, enrollmentMode, deletePending in
      captured.setValue((organizationId, domainId, enrollmentMode, deletePending))
      return .mock
    })

    configureOrganizationService(service)

    _ = try await domain.updateEnrollmentMode(.automaticSuggestion, deletePending: true)

    let params = try #require(captured.value)
    #expect(params.0 == domain.organizationId)
    #expect(params.1 == domain.id)
    #expect(params.2 == OrganizationDomain.EnrollmentMode.automaticSuggestion.rawValue)
    #expect(params.3 == true)
  }

  @Test
  func revokeOrganizationInvitationUsesOrganizationServiceRevokeOrganizationInvitation() async throws {
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
  func acceptUserOrganizationInvitationUsesOrganizationServiceAcceptUserOrganizationInvitation() async throws {
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
  func acceptOrganizationSuggestionUsesOrganizationServiceAcceptOrganizationSuggestion() async throws {
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
  func acceptOrganizationMembershipRequestUsesOrganizationServiceAcceptOrganizationMembershipRequest() async throws {
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
  func rejectOrganizationMembershipRequestUsesOrganizationServiceRejectOrganizationMembershipRequest() async throws {
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
