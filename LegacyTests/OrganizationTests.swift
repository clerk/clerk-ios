import ConcurrencyExtras
import FactoryKit
import Foundation
import Mocker
import Testing

@testable import ClerkKit

@Suite(.serialized) final class SerializedOrganizationTests {

  init() {
  TestContainer.reset()
  Container.shared.clerk.register { @MainActor in
    let clerk = Clerk()
    clerk.client = .mock
    return clerk
  }
  }

  @MainActor
  @Test func testUpdate() async throws {
  let requestHandled = LockIsolated(false)
  let org = Organization.mock
  let originalUrl = mockBaseUrl.appending(path: "/v1/organizations/\(org.id)")
  var mock = Mock(
    url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
    data: [
    .patch: try! JSONEncoder.clerkEncoder.encode(ClientResponse<Organization>(response: .mock, client: .mock))
    ])
  mock.onRequestHandler = OnRequestHandler { request in
    #expect(request.httpMethod == "PATCH")
    #expect(request.url!.query()!.contains("_clerk_session_id"))
    #expect(request.urlEncodedFormBody["name"] == "new name")
    #expect(request.urlEncodedFormBody["slug"] == "new-slug")
    requestHandled.setValue(true)
  }
  mock.register()
  try await org.update(name: "new name", slug: "new-slug")
  #expect(requestHandled.value)
  }

  @MainActor
  @Test func testDestroy() async throws {
  let requestHandled = LockIsolated(false)
  let org = Organization.mock
  let originalUrl = mockBaseUrl.appending(path: "/v1/organizations/\(org.id)")
  var mock = Mock(
    url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
    data: [
    .delete: try! JSONEncoder.clerkEncoder.encode(ClientResponse<Organization>(response: .mock, client: .mock))
    ])
  mock.onRequestHandler = OnRequestHandler { request in
    #expect(request.httpMethod == "DELETE")
    #expect(request.url!.query()!.contains("_clerk_session_id"))
    requestHandled.setValue(true)
  }
  mock.register()
  try await org.destroy()
  #expect(requestHandled.value)
  }

  @MainActor
  @Test func testSetLogo() async throws {
  let requestHandled = LockIsolated(false)
  let org = Organization.mock
  let originalUrl = mockBaseUrl.appending(path: "/v1/organizations/\(org.id)/logo")
  var mock = Mock(
    url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
    data: [
    .put: try! JSONEncoder.clerkEncoder.encode(
      ClientResponse<Organization>(response: .mock, client: .mock)
    )
    ])
  mock.onRequestHandler = OnRequestHandler { request in
    #expect(request.httpMethod == "PUT")
    #expect(request.url!.query()!.contains("_clerk_session_id"))
    #expect(request.value(forHTTPHeaderField: "Content-Type")!.contains("multipart/form-data; boundary="))
    requestHandled.setValue(true)
  }
  mock.register()
  try await org.setLogo(imageData: Data())
  #expect(requestHandled.value)
  }

  @MainActor
  @Test func testGetRoles() async throws {
  let requestHandled = LockIsolated(false)
  let org = Organization.mock
  let originalUrl = mockBaseUrl.appending(path: "/v1/organizations/\(org.id)/roles")
  var mock = Mock(
    url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
    data: [
    .get: try! JSONEncoder.clerkEncoder.encode(
      ClientResponse<ClerkPaginatedResponse<RoleResource>>(response: .init(data: [.mock], totalCount: 1), client: .mock)
    )
    ])
  mock.onRequestHandler = OnRequestHandler { request in
    #expect(request.httpMethod == "GET")
    #expect(request.url!.query()!.contains("_clerk_session_id"))
    #expect(request.url!.query()!.contains("limit"))
    #expect(request.url!.query()!.contains("offset"))
    requestHandled.setValue(true)
  }
  mock.register()
  _ = try await org.getRoles()
  #expect(requestHandled.value)
  }

  private typealias TestMembershipParams = (query: String?, role: [String]?)

  @MainActor
  @Test(
  "Test Get Memberships",
  arguments: [
    (query: "query", role: ["org:role1", "org:role2"]),
    (query: nil, role: nil)
  ])
  private func testGetMemberships(params: TestMembershipParams) async throws {
  let requestHandled = LockIsolated(false)
  let org = Organization.mock
  let originalUrl = mockBaseUrl.appending(path: "/v1/organizations/\(org.id)/memberships")
  var mock = Mock(
    url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
    data: [
    .get: try! JSONEncoder.clerkEncoder.encode(ClientResponse<ClerkPaginatedResponse<OrganizationMembership>>(response: .init(data: [.mockWithUserData], totalCount: 1), client: .mock))
    ])
  mock.onRequestHandler = OnRequestHandler { request in
    #expect(request.httpMethod == "GET")
    #expect(request.url!.query()!.contains("_clerk_session_id"))
    #expect(request.url!.query()!.contains("limit"))
    #expect(request.url!.query()!.contains("offset"))
    #expect(request.url!.query()!.contains("paginated=true"))

    if let query = params.query {
    #expect(request.url!.query()!.contains("query=\(query)"))
    } else {
    #expect(!request.url!.query()!.contains("query"))
    }

    if let role = params.role {
    for r in role {
      #expect(request.url!.query()!.contains("role%5B%5D=\(r)"))  //role[] gets encoded
    }
    } else {
    #expect(!request.url!.query()!.contains("role%5B%5D"))  //role[] gets encoded
    }

    requestHandled.setValue(true)
  }
  mock.register()
  _ = try await org.getMemberships(query: params.query, role: params.role)
  #expect(requestHandled.value)
  }

  @MainActor
  @Test func testAddMember() async throws {
  let requestHandled = LockIsolated(false)
  let org = Organization.mock
  let originalUrl = mockBaseUrl.appending(path: "/v1/organizations/\(org.id)/memberships")
  var mock = Mock(
    url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
    data: [
    .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationMembership>(response: .mockWithUserData, client: .mock))
    ])
  mock.onRequestHandler = OnRequestHandler { request in
    #expect(request.httpMethod == "POST")
    #expect(request.url!.query()!.contains("_clerk_session_id"))
    #expect(request.urlEncodedFormBody["user_id"] == "1")
    #expect(request.urlEncodedFormBody["role"] == "org:member")
    requestHandled.setValue(true)
  }
  mock.register()
  try await org.addMember(userId: "1", role: "org:member")
  #expect(requestHandled.value)
  }

  @MainActor
  @Test func testUpdateMember() async throws {
  let requestHandled = LockIsolated(false)
  let org = Organization.mock
  let user = User.mock
  let originalUrl = mockBaseUrl.appending(path: "/v1/organizations/\(org.id)/memberships/\(user.id)")
  var mock = Mock(
    url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
    data: [
    .patch: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationMembership>(response: .mockWithUserData, client: .mock))
    ])
  mock.onRequestHandler = OnRequestHandler { request in
    #expect(request.httpMethod == "PATCH")
    #expect(request.url!.query()!.contains("_clerk_session_id"))
    #expect(request.urlEncodedFormBody["role"] == "org:basic")
    requestHandled.setValue(true)
  }
  mock.register()
  try await org.updateMember(userId: user.id, role: "org:basic")
  #expect(requestHandled.value)
  }

  @MainActor
  @Test func testRemoveMember() async throws {
  let requestHandled = LockIsolated(false)
  let org = Organization.mock
  let user = User.mock
  let originalUrl = mockBaseUrl.appending(path: "/v1/organizations/\(org.id)/memberships/\(user.id)")
  var mock = Mock(
    url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
    data: [
    .delete: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationMembership>(response: .mockWithUserData, client: .mock))
    ])
  mock.onRequestHandler = OnRequestHandler { request in
    #expect(request.httpMethod == "DELETE")
    #expect(request.url!.query()!.contains("_clerk_session_id"))
    requestHandled.setValue(true)
  }
  mock.register()
  try await org.removeMember(userId: user.id)
  #expect(requestHandled.value)
  }

  @MainActor
  @Test("Test Get Invitations", arguments: ["pending", nil])
  private func testGetMemberships(status: String?) async throws {
  let requestHandled = LockIsolated(false)
  let org = Organization.mock
  let originalUrl = mockBaseUrl.appending(path: "/v1/organizations/\(org.id)/invitations")
  var mock = Mock(
    url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
    data: [
    .get: try! JSONEncoder.clerkEncoder.encode(ClientResponse<ClerkPaginatedResponse<OrganizationInvitation>>(response: .init(data: [.mock], totalCount: 1), client: .mock))
    ])
  mock.onRequestHandler = OnRequestHandler { request in
    #expect(request.httpMethod == "GET")
    #expect(request.url!.query()!.contains("_clerk_session_id"))
    #expect(request.url!.query()!.contains("limit"))
    #expect(request.url!.query()!.contains("offset"))

    if let status {
    #expect(request.url!.query()!.contains("status=\(status)"))
    } else {
    #expect(!request.url!.query()!.contains("status"))
    }

    requestHandled.setValue(true)
  }
  mock.register()
  _ = try await org.getInvitations(status: status)
  #expect(requestHandled.value)
  }

  @MainActor
  @Test func testInviteMember() async throws {
  let requestHandled = LockIsolated(false)
  let org = Organization.mock
  let user = User.mock
  let originalUrl = mockBaseUrl.appending(path: "/v1/organizations/\(org.id)/invitations")
  var mock = Mock(
    url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
    data: [
    .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationInvitation>(response: .mock, client: .mock))
    ])
  mock.onRequestHandler = OnRequestHandler { request in
    #expect(request.httpMethod == "POST")
    #expect(request.url!.query()!.contains("_clerk_session_id"))
    #expect(request.urlEncodedFormBody["email_address"] == user.primaryEmailAddress!.emailAddress)
    #expect(request.urlEncodedFormBody["role"] == "org:member")
    requestHandled.setValue(true)
  }
  mock.register()
  try await org.inviteMember(emailAddress: user.primaryEmailAddress!.emailAddress, role: "org:member")
  #expect(requestHandled.value)
  }

  @MainActor
  @Test func testCreateDomain() async throws {
  let requestHandled = LockIsolated(false)
  let org = Organization.mock
  let originalUrl = mockBaseUrl.appending(path: "/v1/organizations/\(org.id)/domains")
  var mock = Mock(
    url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
    data: [
    .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationDomain>(response: .mock, client: .mock))
    ])
  mock.onRequestHandler = OnRequestHandler { request in
    #expect(request.httpMethod == "POST")
    #expect(request.url!.query()!.contains("_clerk_session_id"))
    #expect(request.urlEncodedFormBody["name"] == "domain.name")
    requestHandled.setValue(true)
  }
  mock.register()
  try await org.createDomain(domainName: "domain.name")
  #expect(requestHandled.value)
  }

  @MainActor
  @Test("Test Get Domains", arguments: ["automatic_enrollment", nil])
  private func testGetDomains(enrollmentMode: String?) async throws {
  let requestHandled = LockIsolated(false)
  let org = Organization.mock
  let originalUrl = mockBaseUrl.appending(path: "/v1/organizations/\(org.id)/domains")
  var mock = Mock(
    url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
    data: [
    .get: try! JSONEncoder.clerkEncoder.encode(ClientResponse<ClerkPaginatedResponse<OrganizationDomain>>(response: .init(data: [.mock], totalCount: 1), client: .mock))
    ])
  mock.onRequestHandler = OnRequestHandler { request in
    #expect(request.httpMethod == "GET")
    #expect(request.url!.query()!.contains("_clerk_session_id"))
    #expect(request.url!.query()!.contains("limit"))
    #expect(request.url!.query()!.contains("offset"))

    if let enrollmentMode {
    #expect(request.url!.query()!.contains("enrollment_mode=\(enrollmentMode)"))
    } else {
    #expect(!request.url!.query()!.contains("enrollment_mode"))
    }

    requestHandled.setValue(true)
  }
  mock.register()
  _ = try await org.getDomains(enrollmentMode: enrollmentMode)
  #expect(requestHandled.value)
  }

  @MainActor
  @Test func testGetDomain() async throws {
  let requestHandled = LockIsolated(false)
  let org = Organization.mock
  let domain = OrganizationDomain.mock
  let originalUrl = mockBaseUrl.appending(path: "/v1/organizations/\(org.id)/domains/\(domain.id)")
  var mock = Mock(
    url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
    data: [
    .get: try! JSONEncoder.clerkEncoder.encode(ClientResponse<OrganizationDomain>(response: .mock, client: .mock))
    ])
  mock.onRequestHandler = OnRequestHandler { request in
    #expect(request.httpMethod == "GET")
    #expect(request.url!.query()!.contains("_clerk_session_id"))
    requestHandled.setValue(true)
  }
  mock.register()
  _ = try await org.getDomain(domainId: domain.id)
  #expect(requestHandled.value)
  }

  @MainActor
  @Test("Test Get Membership Requests", arguments: ["pending", nil])
  private func testGetMembershipRequests(status: String?) async throws {
  let requestHandled = LockIsolated(false)
  let org = Organization.mock
  let originalUrl = mockBaseUrl.appending(path: "/v1/organizations/\(org.id)/membership_requests")
  var mock = Mock(
    url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
    data: [
    .get: try! JSONEncoder.clerkEncoder.encode(
      ClientResponse<ClerkPaginatedResponse<OrganizationMembershipRequest>>(response: .init(data: [.mock], totalCount: 1), client: .mock)
    )
    ])
  mock.onRequestHandler = OnRequestHandler { request in
    #expect(request.httpMethod == "GET")
    #expect(request.url!.query()!.contains("_clerk_session_id"))
    #expect(request.url!.query()!.contains("limit"))
    #expect(request.url!.query()!.contains("offset"))

    if let status {
    #expect(request.url!.query()!.contains("status=\(status)"))
    } else {
    #expect(!request.url!.query()!.contains("status"))
    }

    requestHandled.setValue(true)
  }
  mock.register()
  _ = try await org.getMembershipRequests(status: status)
  #expect(requestHandled.value)
  }

}

@Suite(.serialized) final class SerializedOrganizationDomainTests {

  init() {
  TestContainer.reset()
  Container.shared.clerk.register { @MainActor in
    let clerk = Clerk()
    clerk.client = .mock
    return clerk
  }
  }

  @MainActor
  @Test func testDelete() async throws {
  let requestHandled = LockIsolated(false)
  let org = Organization.mock
  let domain = OrganizationDomain.mock
  let originalUrl = mockBaseUrl.appending(path: "/v1/organizations/\(org.id)/domains/\(domain.id)")
  var mock = Mock(
    url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
    data: [
    .delete: try! JSONEncoder.clerkEncoder.encode(
      ClientResponse<DeletedObject>(response: .mock, client: .mock)
    )
    ])
  mock.onRequestHandler = OnRequestHandler { request in
    #expect(request.httpMethod == "DELETE")
    requestHandled.setValue(true)
  }
  mock.register()
  try await domain.delete()
  #expect(requestHandled.value)
  }

  @MainActor
  @Test func testPrepareAffiliationVerification() async throws {
  let requestHandled = LockIsolated(false)
  let org = Organization.mock
  let domain = OrganizationDomain.mock
  let originalUrl = mockBaseUrl.appending(path: "/v1/organizations/\(org.id)/domains/\(domain.id)/prepare_affiliation_verification")
  var mock = Mock(
    url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
    data: [
    .post: try! JSONEncoder.clerkEncoder.encode(
      ClientResponse<OrganizationDomain>(response: .mock, client: .mock)
    )
    ])
  mock.onRequestHandler = OnRequestHandler { request in
    #expect(request.httpMethod == "POST")
    #expect(request.urlEncodedFormBody["affiliation_email_address"] == User.mock.primaryEmailAddress!.emailAddress)
    requestHandled.setValue(true)
  }
  mock.register()
  try await domain.prepareAffiliationVerification(affiliationEmailAddress: User.mock.primaryEmailAddress!.emailAddress)
  #expect(requestHandled.value)
  }

  @MainActor
  @Test func testAttemptAffiliationVerification() async throws {
  let requestHandled = LockIsolated(false)
  let org = Organization.mock
  let domain = OrganizationDomain.mock
  let code = UUID().uuidString
  let originalUrl = mockBaseUrl.appending(path: "/v1/organizations/\(org.id)/domains/\(domain.id)/attempt_affiliation_verification")
  var mock = Mock(
    url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
    data: [
    .post: try! JSONEncoder.clerkEncoder.encode(
      ClientResponse<OrganizationDomain>(response: .mock, client: .mock)
    )
    ])
  mock.onRequestHandler = OnRequestHandler { request in
    #expect(request.httpMethod == "POST")
    #expect(request.urlEncodedFormBody["code"] == code)
    requestHandled.setValue(true)
  }
  mock.register()
  try await domain.attemptAffiliationVerification(code: code)
  #expect(requestHandled.value)
  }

}

@Suite(.serialized) final class SerializedOrganizationInvitationTests {

  init() {
  TestContainer.reset()
  Container.shared.clerk.register { @MainActor in
    let clerk = Clerk()
    clerk.client = .mock
    return clerk
  }
  }

  @MainActor
  @Test func testRevoke() async throws {
  let requestHandled = LockIsolated(false)
  let org = Organization.mock
  let invitation = OrganizationInvitation.mock
  let originalUrl = mockBaseUrl.appending(path: "/v1/organizations/\(org.id)/invitations/\(invitation.id)/revoke")
  var mock = Mock(
    url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
    data: [
    .post: try! JSONEncoder.clerkEncoder.encode(
      ClientResponse<OrganizationInvitation>(response: .mock, client: .mock)
    )
    ])
  mock.onRequestHandler = OnRequestHandler { request in
    #expect(request.httpMethod == "POST")
    requestHandled.setValue(true)
  }
  mock.register()
  try await invitation.revoke()
  #expect(requestHandled.value)
  }

}

@Suite(.serialized) final class SerializedOrganizationMembershipTests {

  init() {
  TestContainer.reset()
  Container.shared.clerk.register { @MainActor in
    let clerk = Clerk()
    clerk.client = .mock
    return clerk
  }
  }

  @MainActor
  @Test func testDestroyWhenUserDataIsPresent() async throws {
  let requestHandled = LockIsolated(false)
  let org = Organization.mock
  let membership = OrganizationMembership.mockWithUserData
  let originalUrl = mockBaseUrl.appending(path: "/v1/organizations/\(org.id)/memberships/\(membership.publicUserData!.userId!)")
  var mock = Mock(
    url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
    data: [
    .delete: try! JSONEncoder.clerkEncoder.encode(
      ClientResponse<OrganizationMembership>(response: .mockWithUserData, client: .mock)
    )
    ])
  mock.onRequestHandler = OnRequestHandler { request in
    #expect(request.httpMethod == "DELETE")
    requestHandled.setValue(true)
  }
  mock.register()
  try await membership.destroy()
  #expect(requestHandled.value)
  }

  @MainActor
  @Test func testDestroyWhenUserDataIsNil() async throws {
  let membership = OrganizationMembership.mockWithoutUserData
  await #expect(
    throws: Error.self,
    performing: {
    try await membership.destroy()
    })
  }

  @MainActor
  @Test func testUpdateWhenUserDataIsPresent() async throws {
  let requestHandled = LockIsolated(false)
  let org = Organization.mock
  let membership = OrganizationMembership.mockWithUserData
  let role = "org:member"
  let originalUrl = mockBaseUrl.appending(path: "/v1/organizations/\(org.id)/memberships/\(membership.publicUserData!.userId!)")
  var mock = Mock(
    url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
    data: [
    .patch: try! JSONEncoder.clerkEncoder.encode(
      ClientResponse<OrganizationMembership>(response: .mockWithUserData, client: .mock)
    )
    ])
  mock.onRequestHandler = OnRequestHandler { request in
    #expect(request.httpMethod == "PATCH")
    #expect(request.urlEncodedFormBody["role"] == role)
    requestHandled.setValue(true)
  }
  mock.register()
  try await membership.update(role: role)
  #expect(requestHandled.value)
  }

  @MainActor
  @Test func testUpdateWhenUserDataIsNil() async throws {
  let membership = OrganizationMembership.mockWithoutUserData
  await #expect(
    throws: Error.self,
    performing: {
    try await membership.update(role: "org:member")
    })
  }

}

@Suite(.serialized) final class SerializedOrganizationMembershipRequestTests {

  init() {
  TestContainer.reset()
  Container.shared.clerk.register { @MainActor in
    let clerk = Clerk()
    clerk.client = .mock
    return clerk
  }
  }

  @MainActor
  @Test func testAccept() async throws {
  let requestHandled = LockIsolated(false)
  let org = Organization.mock
  let membershipRequest = OrganizationMembershipRequest.mock
  let originalUrl = mockBaseUrl.appending(path: "/v1/organizations/\(org.id)/membership_requests/\(membershipRequest.id)/accept")
  var mock = Mock(
    url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
    data: [
    .post: try! JSONEncoder.clerkEncoder.encode(
      ClientResponse<OrganizationMembershipRequest>(response: .mock, client: .mock)
    )
    ])
  mock.onRequestHandler = OnRequestHandler { request in
    #expect(request.httpMethod == "POST")
    requestHandled.setValue(true)
  }
  mock.register()
  try await membershipRequest.accept()
  #expect(requestHandled.value)
  }

  @MainActor
  @Test func testReject() async throws {
  let requestHandled = LockIsolated(false)
  let org = Organization.mock
  let membershipRequest = OrganizationMembershipRequest.mock
  let originalUrl = mockBaseUrl.appending(path: "/v1/organizations/\(org.id)/membership_requests/\(membershipRequest.id)/reject")
  var mock = Mock(
    url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
    data: [
    .post: try! JSONEncoder.clerkEncoder.encode(
      ClientResponse<OrganizationMembershipRequest>(response: .mock, client: .mock)
    )
    ])
  mock.onRequestHandler = OnRequestHandler { request in
    #expect(request.httpMethod == "POST")
    requestHandled.setValue(true)
  }
  mock.register()
  try await membershipRequest.reject()
  #expect(requestHandled.value)
  }

}

@Suite(.serialized) final class SerializedOrganizationSuggestionTests {

  init() {
  TestContainer.reset()
  Container.shared.clerk.register { @MainActor in
    let clerk = Clerk()
    clerk.client = .mock
    return clerk
  }
  }

  @MainActor
  @Test func testAccept() async throws {
  let requestHandled = LockIsolated(false)
  let orgSuggestion = OrganizationSuggestion.mock
  let originalUrl = mockBaseUrl.appending(path: "/v1/me/organization_suggestions/\(orgSuggestion.id)/accept")
  var mock = Mock(
    url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
    data: [
    .post: try! JSONEncoder.clerkEncoder.encode(
      ClientResponse<OrganizationSuggestion>(response: .mock, client: .mock)
    )
    ])
  mock.onRequestHandler = OnRequestHandler { request in
    #expect(request.httpMethod == "POST")
    requestHandled.setValue(true)
  }
  mock.register()
  try await orgSuggestion.accept()
  #expect(requestHandled.value)
  }

}

@Suite(.serialized) final class SerializedUserOrganizationInvitationTests {

  init() {
  TestContainer.reset()
  Container.shared.clerk.register { @MainActor in
    let clerk = Clerk()
    clerk.client = .mock
    return clerk
  }
  }

  @MainActor
  @Test func testAccept() async throws {
  let requestHandled = LockIsolated(false)
  let userOrgInvitation = UserOrganizationInvitation.mock
  let originalUrl = mockBaseUrl.appending(path: "/v1/me/organization_invitations/\(userOrgInvitation.id)/accept")
  var mock = Mock(
    url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
    data: [
    .post: try! JSONEncoder.clerkEncoder.encode(
      ClientResponse<UserOrganizationInvitation>(response: .mock, client: .mock)
    )
    ])
  mock.onRequestHandler = OnRequestHandler { request in
    #expect(request.httpMethod == "POST")
    requestHandled.setValue(true)
  }
  mock.register()

  try await userOrgInvitation.accept()
  #expect(requestHandled.value)
  }

}
