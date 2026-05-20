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

  var membershipsPager = OrganizationAccountListPager<OrganizationMembership>()
  var invitationsPager = OrganizationAccountListPager<OrganizationInvitation>()
  var membershipRequestsPager = OrganizationAccountListPager<OrganizationMembershipRequest>()
  var isLoadingMembers = true
  var isLoadingInvitations = true
  var isLoadingMembershipRequests = true
  var roles: [RoleResource] = []
  var hasRoleSetMigration = false
  var mutatingMembershipIds: Set<String> = []
  var revokingInvitationIds: Set<String> = []
  var acceptingMembershipRequestIds: Set<String> = []
  var rejectingMembershipRequestIds: Set<String> = []
  var membershipSearchText = ""
  var membershipSearchQuery = ""
  var error: Error?

  init(pageSize: Int = 10) {
    self.pageSize = pageSize
  }

  func loadInitial(
    organization: Organization?,
    includeMembers: Bool,
    includeInvitations: Bool,
    includeMembershipRequests: Bool
  ) async {
    reset(
      includeMembers: includeMembers,
      includeInvitations: includeInvitations,
      includeMembershipRequests: includeMembershipRequests
    )

    guard let organization, includeMembers || includeInvitations || includeMembershipRequests else {
      isLoadingMembers = false
      isLoadingInvitations = false
      isLoadingMembershipRequests = false
      return
    }

    let shouldLoadRoles = includeMembers || includeInvitations
    if shouldLoadRoles {
      await loadRoles(organization: organization)
    }

    async let membersLoad: Void = includeMembers ? loadMembers(organization: organization) : ()
    async let invitationsLoad: Void = includeInvitations ? loadInvitations(organization: organization) : ()
    async let membershipRequestsLoad: Void = includeMembershipRequests ? loadMembershipRequests(organization: organization) : ()

    _ = await (membersLoad, invitationsLoad, membershipRequestsLoad)
  }

  func refreshMembers(organization: Organization) async {
    async let rolesLoad: Void = loadRoles(organization: organization)
    async let membersLoad: Void = loadMembers(organization: organization)
    _ = await (rolesLoad, membersLoad)
  }

  func refreshInvitations(organization: Organization) async {
    async let rolesLoad: Void = loadRoles(organization: organization)
    async let invitationsLoad: Void = loadInvitations(organization: organization)
    _ = await (rolesLoad, invitationsLoad)
  }

  func searchMembers(organization: Organization, query: String) async {
    guard membershipSearchQuery != query else { return }

    membershipSearchQuery = query
    await loadMembers(organization: organization)
  }

  func loadRoles(organization: Organization) async {
    do {
      let page = try await organization.getRoles(page: 1, pageSize: 20)
      roles = page.data
      hasRoleSetMigration = page.hasRoleSetMigration ?? false
    } catch {
      guard !error.isCancellationError else { return }

      roles = []
      hasRoleSetMigration = false
      ClerkLogger.error("Failed to load organization roles", error: error)
    }
  }

  func loadMembers(organization: Organization) async {
    isLoadingMembers = true
    defer { isLoadingMembers = false }

    do {
      let page = try await organization.getMemberships(
        query: membershipSearchQuery.isEmpty ? nil : membershipSearchQuery,
        page: 1,
        pageSize: pageSize
      )
      membershipsPager.replace(with: page)
    } catch {
      guard !error.isCancellationError else { return }

      self.error = error
      ClerkLogger.error("Failed to load organization members", error: error)
    }
  }

  func loadMoreMembers(organization: Organization) async {
    guard !membershipsPager.isLoadingMore, membershipsPager.hasNextPage else { return }

    membershipsPager.isLoadingMore = true
    defer { membershipsPager.isLoadingMore = false }

    do {
      let page = try await organization.getMemberships(
        query: membershipSearchQuery.isEmpty ? nil : membershipSearchQuery,
        offset: membershipsPager.offset,
        pageSize: pageSize
      )
      membershipsPager.append(page)
    } catch {
      guard !error.isCancellationError else { return }

      self.error = error
      ClerkLogger.error("Failed to load more organization members", error: error)
    }
  }

  func loadInvitations(organization: Organization) async {
    isLoadingInvitations = true
    defer { isLoadingInvitations = false }

    do {
      let page = try await organization.getInvitations(page: 1, pageSize: pageSize, status: ["pending"])
      invitationsPager.replace(with: page)
    } catch {
      guard !error.isCancellationError else { return }

      self.error = error
      ClerkLogger.error("Failed to load organization invitations", error: error)
    }
  }

  func loadMoreInvitations(organization: Organization) async {
    guard !invitationsPager.isLoadingMore, invitationsPager.hasNextPage else { return }

    invitationsPager.isLoadingMore = true
    defer { invitationsPager.isLoadingMore = false }

    do {
      let page = try await organization.getInvitations(
        offset: invitationsPager.offset,
        pageSize: pageSize,
        status: ["pending"]
      )
      invitationsPager.append(page)
    } catch {
      guard !error.isCancellationError else { return }

      self.error = error
      ClerkLogger.error("Failed to load more organization invitations", error: error)
    }
  }

  func loadMembershipRequests(organization: Organization) async {
    isLoadingMembershipRequests = true
    defer { isLoadingMembershipRequests = false }

    do {
      let page = try await organization.getMembershipRequests(page: 1, pageSize: pageSize, status: "pending")
      membershipRequestsPager.replace(with: page)
    } catch {
      guard !error.isCancellationError else { return }

      self.error = error
      ClerkLogger.error("Failed to load organization membership requests", error: error)
    }
  }

  func loadMoreMembershipRequests(organization: Organization) async {
    guard !membershipRequestsPager.isLoadingMore, membershipRequestsPager.hasNextPage else { return }

    membershipRequestsPager.isLoadingMore = true
    defer { membershipRequestsPager.isLoadingMore = false }

    do {
      let page = try await organization.getMembershipRequests(
        offset: membershipRequestsPager.offset,
        pageSize: pageSize,
        status: "pending"
      )
      membershipRequestsPager.append(page)
    } catch {
      guard !error.isCancellationError else { return }

      self.error = error
      ClerkLogger.error("Failed to load more organization membership requests", error: error)
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
      membershipsPager.replace(updatedMembership)
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
      membershipsPager.remove(membership)
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

      async let requestsLoad: Void = loadMembershipRequests(organization: organization)
      async let membersLoad: Void = reloadMembers ? loadMembers(organization: organization) : ()
      _ = await (requestsLoad, membersLoad)
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
      await loadMembershipRequests(organization: organization)
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
  fileprivate func reset(
    includeMembers: Bool,
    includeInvitations: Bool,
    includeMembershipRequests: Bool
  ) {
    membershipsPager = OrganizationAccountListPager()
    invitationsPager = OrganizationAccountListPager()
    membershipRequestsPager = OrganizationAccountListPager()
    isLoadingMembers = includeMembers
    isLoadingInvitations = includeInvitations
    isLoadingMembershipRequests = includeMembershipRequests
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
