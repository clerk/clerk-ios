//
//  OrganizationMembersDataSource.swift
//

#if os(iOS) || os(macOS)

import ClerkKit
import Foundation
import Observation

@MainActor
@Observable
final class OrganizationMembersDataSource {
  let pageSize: Int

  let members = OrganizationPagedList<OrganizationMembership>(name: "members")
  let invitations = OrganizationPagedList<OrganizationInvitation>(name: "invitations")
  let membershipRequests = OrganizationPagedList<OrganizationMembershipRequest>(name: "membership requests")
  var roles: [RoleResource] = []
  var hasRoleSetMigration = false
  var mutatingMembershipIds: Set<String> = []
  var revokingInvitationIds: Set<String> = []
  var acceptingMembershipRequestIds: Set<String> = []
  var rejectingMembershipRequestIds: Set<String> = []
  var membershipSearchText = ""
  /// The query of the latest members load.
  private(set) var membershipSearchQuery = ""
  var error: Error?

  @ObservationIgnored private var organizationLoadID = 0

  init(pageSize: Int = 10) {
    self.pageSize = pageSize
    let reportError: @MainActor (Error) -> Void = { [weak self] error in
      self?.error = error
    }
    members.onError = reportError
    invitations.onError = reportError
    membershipRequests.onError = reportError
  }

  func loadInitial(
    organization: Organization?,
    includeMembers: Bool,
    includeInvitations: Bool,
    includeMembershipRequests: Bool
  ) async {
    organizationLoadID += 1
    let loadID = organizationLoadID
    reset(
      includeMembers: includeMembers && organization != nil,
      includeInvitations: includeInvitations && organization != nil,
      includeMembershipRequests: includeMembershipRequests && organization != nil
    )

    guard let organization else { return }

    if includeMembers || includeInvitations {
      await loadRoles(organization: organization)
    }
    guard loadID == organizationLoadID else { return }

    var loads: [Task<Void, Never>] = []
    if includeMembers {
      let query = membershipSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
      loads.append(reloadMembers(organization: organization, query: query))
    }
    if includeInvitations {
      loads.append(invitations.reload(invitationsFetch(organization: organization)))
    }
    if includeMembershipRequests {
      loads.append(membershipRequests.reload(membershipRequestsFetch(organization: organization)))
    }
    for load in loads {
      await load.value
    }
  }

  func refreshMembers(organization: Organization) async {
    async let rolesLoad: Void = loadRoles(organization: organization)
    async let membersLoad: Void = members.refresh()
    _ = await (rolesLoad, membersLoad)
  }

  func refreshInvitations(organization: Organization) async {
    async let rolesLoad: Void = loadRoles(organization: organization)
    async let invitationsLoad: Void = invitations.refresh()
    _ = await (rolesLoad, invitationsLoad)
  }

  func refreshMembershipRequests() async {
    await membershipRequests.refresh()
  }

  /// Loads members matching `query`, unless the latest load already uses it and didn't fail.
  func searchMembers(organization: Organization, query: String) {
    guard query != membershipSearchQuery || (!members.isLoading && !members.hasLoaded) else { return }

    reloadMembers(organization: organization, query: query)
  }

  func loadInvitations(organization: Organization) async {
    await invitations.reload(invitationsFetch(organization: organization)).value
  }

  func loadRoles(organization: Organization) async {
    let loadID = organizationLoadID
    do {
      let page = try await organization.getRoles(page: 1, pageSize: 20)
      guard loadID == organizationLoadID else { return }

      roles = page.data
      hasRoleSetMigration = page.hasRoleSetMigration ?? false
    } catch {
      guard loadID == organizationLoadID, !error.isCancellationError else { return }

      roles = []
      hasRoleSetMigration = false
      ClerkLogger.error("Failed to load organization roles", error: error)
    }
  }

  func updateMemberRole(_ membership: OrganizationMembership, role: RoleResource) async {
    guard role.key != membership.role else { return }
    guard !hasRoleSetMigration else { return }
    guard !mutatingMembershipIds.contains(membership.id) else { return }

    mutatingMembershipIds.insert(membership.id)
    defer { mutatingMembershipIds.remove(membership.id) }

    do {
      let updatedMembership = try await membership.update(role: role.key)
      members.update { $0.replace(updatedMembership) }
    } catch {
      self.error = error
      ClerkLogger.error("Failed to update organization member role", error: error)
    }
  }

  func removeMember(_ membership: OrganizationMembership) async {
    guard !mutatingMembershipIds.contains(membership.id) else { return }

    mutatingMembershipIds.insert(membership.id)
    defer { mutatingMembershipIds.remove(membership.id) }

    do {
      try await membership.destroy()
      members.update { $0.remove(membership) }
    } catch {
      self.error = error
      ClerkLogger.error("Failed to remove organization member", error: error)
    }
  }

  func revokeInvitation(_ invitation: OrganizationInvitation, organization: Organization) async {
    guard !revokingInvitationIds.contains(invitation.id) else { return }

    revokingInvitationIds.insert(invitation.id)
    defer { revokingInvitationIds.remove(invitation.id) }

    do {
      try await invitation.revoke()
      await loadInvitations(organization: organization)
    } catch {
      self.error = error
      ClerkLogger.error("Failed to revoke organization invitation", error: error)
    }
  }

  func acceptMembershipRequest(
    _ request: OrganizationMembershipRequest,
    organization: Organization,
    reloadMembers: Bool
  ) async {
    guard !acceptingMembershipRequestIds.contains(request.id),
          !rejectingMembershipRequestIds.contains(request.id)
    else { return }

    acceptingMembershipRequestIds.insert(request.id)
    defer { acceptingMembershipRequestIds.remove(request.id) }

    do {
      try await request.accept()

      let requestsLoad = membershipRequests.reload(membershipRequestsFetch(organization: organization))
      if reloadMembers {
        await self.reloadMembers(organization: organization, query: membershipSearchQuery).value
      }
      await requestsLoad.value
    } catch {
      self.error = error
      ClerkLogger.error("Failed to accept organization membership request", error: error)
    }
  }

  func rejectMembershipRequest(_ request: OrganizationMembershipRequest, organization: Organization) async {
    guard !acceptingMembershipRequestIds.contains(request.id),
          !rejectingMembershipRequestIds.contains(request.id)
    else { return }

    rejectingMembershipRequestIds.insert(request.id)
    defer { rejectingMembershipRequestIds.remove(request.id) }

    do {
      try await request.reject()
      await membershipRequests.reload(membershipRequestsFetch(organization: organization)).value
    } catch {
      self.error = error
      ClerkLogger.error("Failed to reject organization membership request", error: error)
    }
  }

  func roleName(for membership: OrganizationMembership) -> String {
    roleName(for: membership.role, fallback: membership.roleName)
  }

  func roleName(for invitation: OrganizationInvitation) -> String {
    roleName(for: invitation.role)
  }
}

extension OrganizationMembersDataSource {
  @discardableResult
  fileprivate func reloadMembers(organization: Organization, query: String) -> Task<Void, Never> {
    membershipSearchQuery = query
    return members.reload { [pageSize] offset in
      try await organization.getMemberships(query: query.isEmpty ? nil : query, offset: offset, pageSize: pageSize)
    }
  }

  fileprivate func invitationsFetch(organization: Organization) -> OrganizationPagedList<OrganizationInvitation>.Fetch {
    { [pageSize] offset in
      try await organization.getInvitations(offset: offset, pageSize: pageSize, status: ["pending"])
    }
  }

  fileprivate func membershipRequestsFetch(organization: Organization) -> OrganizationPagedList<OrganizationMembershipRequest>.Fetch {
    { [pageSize] offset in
      try await organization.getMembershipRequests(offset: offset, pageSize: pageSize, status: "pending")
    }
  }

  fileprivate func reset(
    includeMembers: Bool,
    includeInvitations: Bool,
    includeMembershipRequests: Bool
  ) {
    members.reset(isLoading: includeMembers)
    invitations.reset(isLoading: includeInvitations)
    membershipRequests.reset(isLoading: includeMembershipRequests)
    roles = []
    hasRoleSetMigration = false
    mutatingMembershipIds = []
    revokingInvitationIds = []
    acceptingMembershipRequestIds = []
    rejectingMembershipRequestIds = []
    error = nil
  }

  fileprivate func roleName(for roleKey: String, fallback: String? = nil) -> String {
    if let role = roles.first(where: { $0.key == roleKey }) {
      return role.name
    }

    if let fallback, !fallback.isEmpty {
      return fallback
    }

    return roleKey
  }
}

#endif
