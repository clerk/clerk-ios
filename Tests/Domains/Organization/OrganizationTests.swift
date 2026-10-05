@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct OrganizationTests {
  private let transport = FakeTransport.mockDefaults()

  init() {
    configureClerkForTesting()
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      transport: transport
    )
  }

  struct MembershipsScenario: Codable, Equatable {
    let query: String?
    let role: [String]?
  }

  struct InvitationsScenario: Codable, Equatable {
    let status: [String]
  }

  struct DomainsScenario: Codable, Equatable {
    let enrollmentMode: OrganizationDomain.EnrollmentMode?
  }

  struct MembershipRequestsScenario: Codable, Equatable {
    let status: String?
  }

  @Test
  func decodesOrganizationWithoutImageUrl() throws {
    let json = Data(
      """
      {
        "object": "organization",
        "id": "org_123",
        "name": "Acme",
        "slug": "acme",
        "has_image": false,
        "max_allowed_memberships": 100,
        "admin_delete_enabled": true,
        "created_at": 0,
        "updated_at": 0,
        "public_metadata": {}
      }
      """.utf8
    )

    let organization = try JSONDecoder.clerkDecoder.decode(Organization.self, from: json)

    #expect(organization.imageUrl == "")
    #expect(!organization.hasImage)
  }

  @Test
  func updateSendsNameAndSlugForOrganization() async throws {
    let organization = Organization.mock

    _ = try await organization.update(name: "New Name", slug: "new-slug")

    let call = try #require(transport.calls.last)
    #expect(call.method == .patch)
    #expect(call.path == "/v1/organizations/\(organization.id)")
    #expect(call.body?["name"]?.stringValue == "New Name")
    #expect(call.body?["slug"]?.stringValue == "new-slug")
  }

  @Test
  func destroyDeletesOrganization() async throws {
    let organization = Organization.mock

    _ = try await organization.destroy()

    let call = try #require(transport.calls.last)
    #expect(call.method == .delete)
    #expect(call.path == "/v1/organizations/\(organization.id)")
  }

  @Test
  func setLogoUploadsImageDataForOrganization() async throws {
    let organization = Organization.mock
    let imageData = Data("fake image data".utf8)

    _ = try await organization.setLogo(imageData: imageData)

    let call = try #require(transport.calls.last)
    #expect(call.method == .put)
    #expect(call.path == "/v1/organizations/\(organization.id)/logo")
    let uploadBody = try #require(call.uploadBody)
    #expect(uploadBody.range(of: imageData) != nil)
  }

  @Test
  func deleteLogoDeletesOrganizationLogo() async throws {
    let organization = Organization.mock

    _ = try await organization.deleteLogo()

    let call = try #require(transport.calls.last)
    #expect(call.method == .delete)
    #expect(call.path == "/v1/organizations/\(organization.id)/logo")
  }

  @Test
  func getRolesSendsPageOffset() async throws {
    let organization = Organization.mock

    _ = try await organization.getRoles(page: 2, pageSize: 10)

    let call = try #require(transport.calls.last)
    #expect(call.path == "/v1/organizations/\(organization.id)/roles")
    #expect(call.query.first { $0.name == "offset" }?.value == "10")
    #expect(call.query.first { $0.name == "limit" }?.value == "10")
  }

  @Test(
    arguments: [
      MembershipsScenario(query: nil, role: nil),
      MembershipsScenario(query: "test", role: nil),
      MembershipsScenario(query: nil, role: ["admin"]),
    ]
  )
  func getMembershipsSendsPageOffsetQueryAndRoles(
    scenario: MembershipsScenario
  ) async throws {
    let organization = Organization.mock

    _ = try await organization.getMemberships(
      query: scenario.query,
      role: scenario.role,
      page: 3,
      pageSize: 10
    )

    let call = try #require(transport.calls.last)
    #expect(call.path == "/v1/organizations/\(organization.id)/memberships")
    #expect(call.query.first { $0.name == "query" }?.value == scenario.query)
    #expect(call.query.filter { $0.name == "role[]" }.compactMap(\.value) == (scenario.role ?? []))
    #expect(call.query.first { $0.name == "offset" }?.value == "20")
    #expect(call.query.first { $0.name == "limit" }?.value == "10")
  }

  @Test
  func getMembershipsWithOffsetSendsOffsetQueryAndRoles() async throws {
    let organization = Organization.mock

    _ = try await organization.getMemberships(
      query: "search",
      role: ["admin"],
      offset: 30,
      pageSize: 10
    )

    let call = try #require(transport.calls.last)
    #expect(call.path == "/v1/organizations/\(organization.id)/memberships")
    #expect(call.query.first { $0.name == "query" }?.value == "search")
    #expect(call.query.filter { $0.name == "role[]" }.compactMap(\.value) == ["admin"])
    #expect(call.query.first { $0.name == "offset" }?.value == "30")
    #expect(call.query.first { $0.name == "limit" }?.value == "10")
  }

  @Test
  func addMemberSendsUserIdAndRole() async throws {
    let organization = Organization.mock

    _ = try await organization.addMember(userId: "user123", role: "org:member")

    let call = try #require(transport.calls.last)
    #expect(call.method == .post)
    #expect(call.path == "/v1/organizations/\(organization.id)/memberships")
    #expect(call.body?["user_id"]?.stringValue == "user123")
    #expect(call.body?["role"]?.stringValue == "org:member")
  }

  @Test
  func updateMemberSendsRoleForUser() async throws {
    let organization = Organization.mock

    _ = try await organization.updateMember(userId: "user123", role: "org:admin")

    let call = try #require(transport.calls.last)
    #expect(call.method == .patch)
    #expect(call.path == "/v1/organizations/\(organization.id)/memberships/user123")
    #expect(call.body?["role"]?.stringValue == "org:admin")
  }

  @Test
  func removeMemberDeletesUserMembership() async throws {
    let organization = Organization.mock

    _ = try await organization.removeMember(userId: "user123")

    let call = try #require(transport.calls.last)
    #expect(call.method == .delete)
    #expect(call.path == "/v1/organizations/\(organization.id)/memberships/user123")
  }

  @Test
  func membershipUpdateSendsRoleForMembershipUser() async throws {
    let membership = OrganizationMembership.mockWithUserData
    let userId = try #require(membership.publicUserData?.userId)

    _ = try await membership.update(role: "org:admin")

    let call = try #require(transport.calls.last)
    #expect(call.method == .patch)
    #expect(call.path == "/v1/organizations/\(membership.organization.id)/memberships/\(userId)")
    #expect(call.body?["role"]?.stringValue == "org:admin")
  }

  @Test
  func membershipDestroyDeletesMembershipUser() async throws {
    let membership = OrganizationMembership.mockWithUserData
    let userId = try #require(membership.publicUserData?.userId)

    _ = try await membership.destroy()

    let call = try #require(transport.calls.last)
    #expect(call.method == .delete)
    #expect(call.path == "/v1/organizations/\(membership.organization.id)/memberships/\(userId)")
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
      InvitationsScenario(status: []),
      InvitationsScenario(status: ["pending", "accepted"]),
    ]
  )
  func getInvitationsSendsPageOffsetAndStatuses(
    scenario: InvitationsScenario
  ) async throws {
    let organization = Organization.mock

    _ = try await organization.getInvitations(
      page: 2,
      pageSize: 10,
      status: scenario.status
    )

    let call = try #require(transport.calls.last)
    #expect(call.path == "/v1/organizations/\(organization.id)/invitations")
    #expect(call.query.first { $0.name == "offset" }?.value == "10")
    #expect(call.query.first { $0.name == "limit" }?.value == "10")
    #expect(call.query.filter { $0.name == "status" }.compactMap(\.value) == scenario.status)
  }

  @Test
  func getInvitationsWithOffsetSendsOffsetAndStatuses() async throws {
    let organization = Organization.mock

    _ = try await organization.getInvitations(
      offset: 30,
      pageSize: 10,
      status: ["pending"]
    )

    let call = try #require(transport.calls.last)
    #expect(call.path == "/v1/organizations/\(organization.id)/invitations")
    #expect(call.query.first { $0.name == "offset" }?.value == "30")
    #expect(call.query.first { $0.name == "limit" }?.value == "10")
    #expect(call.query.filter { $0.name == "status" }.compactMap(\.value) == ["pending"])
  }

  @Test
  func inviteMemberSendsEmailAddressAndRole() async throws {
    let organization = Organization.mock

    _ = try await organization.inviteMember(emailAddress: "user@example.com", role: "org:member")

    let call = try #require(transport.calls.last)
    #expect(call.method == .post)
    #expect(call.path == "/v1/organizations/\(organization.id)/invitations")
    #expect(call.body?["email_address"]?.stringValue == "user@example.com")
    #expect(call.body?["role"]?.stringValue == "org:member")
  }

  @Test
  func inviteMembersSendsEmailAddressesAndRole() async throws {
    let organization = Organization.mock

    _ = try await organization.inviteMembers(
      emailAddresses: ["one@example.com", "two@example.com"],
      role: "org:member"
    )

    let call = try #require(transport.calls.last)
    #expect(call.method == .post)
    #expect(call.path == "/v1/organizations/\(organization.id)/invitations/bulk")
    #expect(call.body?["email_address"] == ["one@example.com", "two@example.com"])
    #expect(call.body?["role"]?.stringValue == "org:member")
  }

  @Test
  func createDomainSendsDomainName() async throws {
    let organization = Organization.mock

    _ = try await organization.createDomain(domainName: "example.com")

    let call = try #require(transport.calls.last)
    #expect(call.method == .post)
    #expect(call.path == "/v1/organizations/\(organization.id)/domains")
    #expect(call.body?["name"]?.stringValue == "example.com")
  }

  @Test(
    arguments: [
      DomainsScenario(enrollmentMode: nil),
      DomainsScenario(enrollmentMode: .unknown("future_mode")),
    ]
  )
  func getDomainsSendsPageOffsetAndEnrollmentMode(
    scenario: DomainsScenario
  ) async throws {
    let organization = Organization.mock

    _ = try await organization.getDomains(
      page: 2,
      pageSize: 10,
      enrollmentMode: scenario.enrollmentMode
    )

    let call = try #require(transport.calls.last)
    #expect(call.path == "/v1/organizations/\(organization.id)/domains")
    #expect(call.query.first { $0.name == "offset" }?.value == "10")
    #expect(call.query.first { $0.name == "limit" }?.value == "10")
    #expect(call.query.first { $0.name == "enrollment_mode" }?.value == scenario.enrollmentMode?.rawValue)
  }

  @Test
  func getDomainsWithEnrollmentModeUsesRawEnrollmentMode() async throws {
    let organization = Organization.mock

    _ = try await organization.getDomains(
      page: 2,
      pageSize: 10,
      enrollmentMode: .automaticInvitation
    )

    let call = try #require(transport.calls.last)
    #expect(call.path == "/v1/organizations/\(organization.id)/domains")
    #expect(call.query.first { $0.name == "offset" }?.value == "10")
    #expect(call.query.first { $0.name == "limit" }?.value == "10")
    #expect(call.query.first { $0.name == "enrollment_mode" }?.value == OrganizationDomain.EnrollmentMode.automaticInvitation.rawValue)
  }

  @Test
  func getDomainsWithOffsetSendsOffsetAndEnrollmentMode() async throws {
    let organization = Organization.mock

    _ = try await organization.getDomains(
      offset: 20,
      pageSize: 10,
      enrollmentMode: OrganizationDomain.EnrollmentMode.automaticSuggestion.rawValue
    )

    let call = try #require(transport.calls.last)
    #expect(call.path == "/v1/organizations/\(organization.id)/domains")
    #expect(call.query.first { $0.name == "offset" }?.value == "20")
    #expect(call.query.first { $0.name == "limit" }?.value == "10")
    #expect(call.query.first { $0.name == "enrollment_mode" }?.value == OrganizationDomain.EnrollmentMode.automaticSuggestion.rawValue)
  }

  @Test
  func getDomainRequestsDomainById() async throws {
    let organization = Organization.mock

    _ = try await organization.getDomain(domainId: "domain123")

    let call = try #require(transport.calls.last)
    #expect(call.method == .get)
    #expect(call.path == "/v1/organizations/\(organization.id)/domains/domain123")
  }

  @Test(
    arguments: [
      MembershipRequestsScenario(status: nil),
      MembershipRequestsScenario(status: "pending"),
    ]
  )
  func getMembershipRequestsSendsPageOffsetAndStatus(
    scenario: MembershipRequestsScenario
  ) async throws {
    let organization = Organization.mock

    _ = try await organization.getMembershipRequests(
      page: 2,
      pageSize: 10,
      status: scenario.status
    )

    let call = try #require(transport.calls.last)
    #expect(call.path == "/v1/organizations/\(organization.id)/membership_requests")
    #expect(call.query.first { $0.name == "offset" }?.value == "10")
    #expect(call.query.first { $0.name == "limit" }?.value == "10")
    #expect(call.query.first { $0.name == "status" }?.value == scenario.status)
  }

  @Test
  func getMembershipRequestsWithOffsetSendsOffsetAndStatus() async throws {
    let organization = Organization.mock

    _ = try await organization.getMembershipRequests(
      offset: 30,
      pageSize: 10,
      status: "pending"
    )

    let call = try #require(transport.calls.last)
    #expect(call.path == "/v1/organizations/\(organization.id)/membership_requests")
    #expect(call.query.first { $0.name == "offset" }?.value == "30")
    #expect(call.query.first { $0.name == "limit" }?.value == "10")
    #expect(call.query.first { $0.name == "status" }?.value == "pending")
  }

  @Test
  func domainDeleteDeletesDomain() async throws {
    let domain = OrganizationDomain.mock

    _ = try await domain.delete()

    let call = try #require(transport.calls.last)
    #expect(call.method == .delete)
    #expect(call.path == "/v1/organizations/\(domain.organizationId)/domains/\(domain.id)")
  }

  @Test
  func prepareAffiliationVerificationSendsAffiliationEmailAddress() async throws {
    let domain = OrganizationDomain.mock

    _ = try await domain.prepareAffiliationVerification(affiliationEmailAddress: "user@example.com")

    let call = try #require(transport.calls.last)
    #expect(call.path == "/v1/organizations/\(domain.organizationId)/domains/\(domain.id)/prepare_affiliation_verification")
    #expect(call.body?["affiliation_email_address"]?.stringValue == "user@example.com")
  }

  @Test
  func sendEmailCodePreparesAffiliationVerification() async throws {
    let domain = OrganizationDomain.mock

    _ = try await domain.sendEmailCode(affiliationEmailAddress: "user@example.com")

    let call = try #require(transport.calls.last)
    #expect(call.path == "/v1/organizations/\(domain.organizationId)/domains/\(domain.id)/prepare_affiliation_verification")
    #expect(call.body?["affiliation_email_address"]?.stringValue == "user@example.com")
  }

  @Test
  func attemptAffiliationVerificationSendsCode() async throws {
    let domain = OrganizationDomain.mock

    _ = try await domain.attemptAffiliationVerification(code: "123456")

    let call = try #require(transport.calls.last)
    #expect(call.path == "/v1/organizations/\(domain.organizationId)/domains/\(domain.id)/attempt_affiliation_verification")
    #expect(call.body?["code"]?.stringValue == "123456")
  }

  @Test
  func verifyCodeAttemptsAffiliationVerification() async throws {
    let domain = OrganizationDomain.mock

    _ = try await domain.verifyCode("123456")

    let call = try #require(transport.calls.last)
    #expect(call.path == "/v1/organizations/\(domain.organizationId)/domains/\(domain.id)/attempt_affiliation_verification")
    #expect(call.body?["code"]?.stringValue == "123456")
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
    domain.verification = .init(status: "verified", strategy: "strategy", attempts: 0)

    #expect(domain.isVerified)

    domain.verification = .init(status: "unverified", strategy: "strategy", attempts: 0)

    #expect(!domain.isVerified)

    domain.verification = nil

    #expect(!domain.isVerified)
  }

  @Test
  func organizationDomainDecodesNullVerification() throws {
    let json = """
    {
      "object": "organization_domain",
      "id": "domain_1",
      "name": "example.com",
      "organization_id": "org_1",
      "enrollment_mode": "manual_invitation",
      "verification": null,
      "affiliation_email_address": null,
      "total_pending_invitations": 0,
      "total_pending_suggestions": 0,
      "created_at": 0,
      "updated_at": 0
    }
    """.data(using: .utf8)!

    let domain = try JSONDecoder.clerkDecoder.decode(OrganizationDomain.self, from: json)

    #expect(domain.verification == nil)
    #expect(!domain.isVerified)
  }

  @Test
  func updateEnrollmentModeSendsModeAndDeletePending() async throws {
    let domain = OrganizationDomain.mock

    _ = try await domain.updateEnrollmentMode(.automaticSuggestion, deletePending: true)

    let call = try #require(transport.calls.last)
    #expect(call.path == "/v1/organizations/\(domain.organizationId)/domains/\(domain.id)/update_enrollment_mode")
    #expect(call.body?["enrollment_mode"]?.stringValue == OrganizationDomain.EnrollmentMode.automaticSuggestion.rawValue)
    #expect(call.body?["delete_pending"]?.boolValue == true)
  }

  @Test
  func invitationRevokeRevokesInvitation() async throws {
    let invitation = OrganizationInvitation.mock

    _ = try await invitation.revoke()

    let call = try #require(transport.calls.last)
    #expect(call.method == .post)
    #expect(call.path == "/v1/organizations/\(invitation.organizationId)/invitations/\(invitation.id)/revoke")
  }

  @Test
  func userInvitationAcceptAcceptsInvitation() async throws {
    let invitation = UserOrganizationInvitation.mock

    _ = try await invitation.accept()

    let call = try #require(transport.calls.last)
    #expect(call.method == .post)
    #expect(call.path == "/v1/me/organization_invitations/\(invitation.id)/accept")
  }

  @Test
  func suggestionAcceptAcceptsSuggestion() async throws {
    let suggestion = OrganizationSuggestion.mock

    _ = try await suggestion.accept()

    let call = try #require(transport.calls.last)
    #expect(call.method == .post)
    #expect(call.path == "/v1/me/organization_suggestions/\(suggestion.id)/accept")
  }

  @Test
  func membershipRequestAcceptAcceptsRequest() async throws {
    let request = OrganizationMembershipRequest.mock

    _ = try await request.accept()

    let call = try #require(transport.calls.last)
    #expect(call.method == .post)
    #expect(call.path == "/v1/organizations/\(request.organizationId)/membership_requests/\(request.id)/accept")
  }

  @Test
  func membershipRequestRejectRejectsRequest() async throws {
    let request = OrganizationMembershipRequest.mock

    _ = try await request.reject()

    let call = try #require(transport.calls.last)
    #expect(call.method == .post)
    #expect(call.path == "/v1/organizations/\(request.organizationId)/membership_requests/\(request.id)/reject")
  }
}
