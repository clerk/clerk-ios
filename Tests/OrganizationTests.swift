//
//  OrganizationTests.swift
//  Clerk
//
//  Created by Mike Pitre on 1/1/26.
//

import Foundation
import Testing

@testable import ClerkKit

@Suite(.serialized)
struct OrganizationTests {

  @Test
  @MainActor
  func testUpdateOrganization() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let organization = Organization.mock
    _ = try? await organization.update(name: "Test Org", slug: "test-org")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/organizations/\(organization.id)", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/organizations/\(organization.id)"))
    #expect(verification.hasMethod("PATCH"))

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["name"] == "Test Org")
    #expect(bodyParams["slug"] == "test-org")
  }

  @Test
  @MainActor
  func testDestroyOrganization() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let organization = Organization.mock
    _ = try? await organization.destroy()

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/organizations/\(organization.id)", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/organizations/\(organization.id)"))
    #expect(verification.hasMethod("DELETE"))
  }

  @Test
  @MainActor
  func testSetOrganizationLogo() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let organization = Organization.mock
    let imageData = Data("image data".utf8)
    _ = try? await organization.setLogo(imageData: imageData)

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/organizations/\(organization.id)/logo", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/organizations/\(organization.id)/logo"))
    #expect(verification.hasMethod("PUT"))
    let contentType = request.value(forHTTPHeaderField: "Content-Type")
    #expect(contentType?.hasPrefix("multipart/form-data") == true)
  }

  @Test
  @MainActor
  func testGetOrganizationRoles() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let organization = Organization.mock
    _ = try? await organization.getRoles(initialPage: 0, pageSize: 10)

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/organizations/\(organization.id)/roles", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/organizations/\(organization.id)/roles"))
    #expect(verification.hasMethod("GET"))
    #expect(verification.hasQueryParameter("offset", value: "0"))
    #expect(verification.hasQueryParameter("limit", value: "10"))
  }

  @Test
  @MainActor
  func testGetOrganizationMemberships() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let organization = Organization.mock
    _ = try? await organization.getMemberships(query: "test", role: ["admin"], initialPage: 0, pageSize: 10)

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/organizations/\(organization.id)/memberships", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/organizations/\(organization.id)/memberships"))
    #expect(verification.hasMethod("GET"))
    #expect(verification.hasQueryParameter("query", value: "test"))
    #expect(verification.hasQueryParameter("paginated", value: "true"))
  }

  @Test
  @MainActor
  func testAddOrganizationMember() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let organization = Organization.mock
    _ = try? await organization.addMember(userId: "user_123", role: "admin")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/organizations/\(organization.id)/memberships", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/organizations/\(organization.id)/memberships"))
    #expect(verification.hasMethod("POST"))

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["user_id"] == "user_123")
    #expect(bodyParams["role"] == "admin")
  }

  @Test
  @MainActor
  func testUpdateOrganizationMember() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let organization = Organization.mock
    _ = try? await organization.updateMember(userId: "user_123", role: "member")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/organizations/\(organization.id)/memberships/user_123", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/organizations/\(organization.id)/memberships/user_123"))
    #expect(verification.hasMethod("PATCH"))

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["role"] == "member")
  }

  @Test
  @MainActor
  func testRemoveOrganizationMember() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let organization = Organization.mock
    _ = try? await organization.removeMember(userId: "user_123")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/organizations/\(organization.id)/memberships/user_123", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/organizations/\(organization.id)/memberships/user_123"))
    #expect(verification.hasMethod("DELETE"))
  }

  @Test
  @MainActor
  func testGetOrganizationInvitations() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let organization = Organization.mock
    _ = try? await organization.getInvitations(initialPage: 0, pageSize: 10, status: "pending")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/organizations/\(organization.id)/invitations", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/organizations/\(organization.id)/invitations"))
    #expect(verification.hasMethod("GET"))
    #expect(verification.hasQueryParameter("status", value: "pending"))
  }

  @Test
  @MainActor
  func testInviteOrganizationMember() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let organization = Organization.mock
    _ = try? await organization.inviteMember(emailAddress: "test@example.com", role: "admin")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/organizations/\(organization.id)/invitations", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/organizations/\(organization.id)/invitations"))
    #expect(verification.hasMethod("POST"))

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["email_address"] == "test@example.com")
    #expect(bodyParams["role"] == "admin")
  }

  @Test
  @MainActor
  func testCreateOrganizationDomain() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let organization = Organization.mock
    _ = try? await organization.createDomain(domainName: "example.com")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/organizations/\(organization.id)/domains", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/organizations/\(organization.id)/domains"))
    #expect(verification.hasMethod("POST"))

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["name"] == "example.com")
  }

  @Test
  @MainActor
  func testGetOrganizationDomains() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let organization = Organization.mock
    _ = try? await organization.getDomains(initialPage: 0, pageSize: 10, enrollmentMode: "automatic")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/organizations/\(organization.id)/domains", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/organizations/\(organization.id)/domains"))
    #expect(verification.hasMethod("GET"))
    #expect(verification.hasQueryParameter("enrollment_mode", value: "automatic"))
  }

  @Test
  @MainActor
  func testGetOrganizationDomain() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let organization = Organization.mock
    _ = try? await organization.getDomain(domainId: "domain_123")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/organizations/\(organization.id)/domains/domain_123", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/organizations/\(organization.id)/domains/domain_123"))
    #expect(verification.hasMethod("GET"))
  }

  @Test
  @MainActor
  func testGetOrganizationMembershipRequests() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let organization = Organization.mock
    _ = try? await organization.getMembershipRequests(initialPage: 0, pageSize: 10, status: "pending")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/organizations/\(organization.id)/membership_requests", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/organizations/\(organization.id)/membership_requests"))
    #expect(verification.hasMethod("GET"))
    #expect(verification.hasQueryParameter("status", value: "pending"))
  }

  @Test
  @MainActor
  func testDeleteOrganizationDomain() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let domain = OrganizationDomain.mock
    _ = try? await domain.delete()

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/organizations/\(domain.organizationId)/domains/\(domain.id)", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/organizations/\(domain.organizationId)/domains/\(domain.id)"))
    #expect(verification.hasMethod("DELETE"))
  }

  @Test
  @MainActor
  func testPrepareOrganizationDomainAffiliationVerification() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let domain = OrganizationDomain.mock
    _ = try? await domain.prepareAffiliationVerification(affiliationEmailAddress: "admin@example.com")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/organizations/\(domain.organizationId)/domains/\(domain.id)/prepare_affiliation_verification", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/organizations/\(domain.organizationId)/domains/\(domain.id)/prepare_affiliation_verification"))
    #expect(verification.hasMethod("POST"))

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["affiliation_email_address"] == "admin@example.com")
  }

  @Test
  @MainActor
  func testAttemptOrganizationDomainAffiliationVerification() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let domain = OrganizationDomain.mock
    _ = try? await domain.attemptAffiliationVerification(code: "123456")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/organizations/\(domain.organizationId)/domains/\(domain.id)/attempt_affiliation_verification", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/organizations/\(domain.organizationId)/domains/\(domain.id)/attempt_affiliation_verification"))
    #expect(verification.hasMethod("POST"))

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["code"] == "123456")
  }

  @Test
  @MainActor
  func testRevokeOrganizationInvitation() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let invitation = OrganizationInvitation.mock
    _ = try? await invitation.revoke()

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/organizations/\(invitation.organizationId)/invitations/\(invitation.id)/revoke", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/organizations/\(invitation.organizationId)/invitations/\(invitation.id)/revoke"))
    #expect(verification.hasMethod("POST"))
  }

  @Test
  @MainActor
  func testDestroyOrganizationMembership() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let membership = OrganizationMembership.mockWithUserData
    guard let userId = membership.publicUserData?.userId else {
      Issue.record("membership.publicUserData.userId is nil")
      return
    }
    let expectedPath = "/v1/organizations/\(membership.organization.id)/memberships/\(userId)"
    _ = try? await membership.destroy()

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: expectedPath, from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath(expectedPath))
    #expect(verification.hasMethod("DELETE"))
  }

  @Test
  @MainActor
  func testAcceptUserOrganizationInvitation() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let invitation = UserOrganizationInvitation.mock
    _ = try? await invitation.accept()

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/organization_invitations/\(invitation.id)/accept", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/organization_invitations/\(invitation.id)/accept"))
    #expect(verification.hasMethod("POST"))
  }

  @Test
  @MainActor
  func testAcceptOrganizationSuggestion() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let suggestion = OrganizationSuggestion.mock
    _ = try? await suggestion.accept()

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/organization_suggestions/\(suggestion.id)/accept", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/organization_suggestions/\(suggestion.id)/accept"))
    #expect(verification.hasMethod("POST"))
  }

  @Test
  @MainActor
  func testAcceptOrganizationMembershipRequest() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let membershipRequest = OrganizationMembershipRequest.mock
    _ = try? await membershipRequest.accept()

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/organizations/\(membershipRequest.organizationId)/membership_requests/\(membershipRequest.id)/accept", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/organizations/\(membershipRequest.organizationId)/membership_requests/\(membershipRequest.id)/accept"))
    #expect(verification.hasMethod("POST"))
  }

  @Test
  @MainActor
  func testRejectOrganizationMembershipRequest() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let membershipRequest = OrganizationMembershipRequest.mock
    _ = try? await membershipRequest.reject()

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/organizations/\(membershipRequest.organizationId)/membership_requests/\(membershipRequest.id)/reject", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/organizations/\(membershipRequest.organizationId)/membership_requests/\(membershipRequest.id)/reject"))
    #expect(verification.hasMethod("POST"))
  }
}
