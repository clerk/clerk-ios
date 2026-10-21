//
//  OrganizationMembersDataSource.swift
//

#if os(iOS) || os(macOS)

import ClerkKit
import Foundation
import Observation

@MainActor
@Observable
final class OrganizationMembersDataSource: OrganizationScopedContent {
  let scope: OrganizationScope
  let members: OrganizationPagedList<OrganizationMembership, String>
  let invitations: OrganizationPagedList<OrganizationInvitation, Void>
  let membershipRequests: OrganizationPagedList<OrganizationMembershipRequest, Void>
  let roles: OrganizationRolesDataSource
  var membershipSearchText = ""
  var error: Error?

  init(scope: OrganizationScope, pageSize: Int = 10) {
    let organization = scope.organization
    self.scope = scope
    members = OrganizationPagedList(name: "members", isLoading: scope.access.contains(.readMemberships)) { query, offset in
      try await organization.getMemberships(query: query.isEmpty ? nil : query, offset: offset, pageSize: pageSize)
    }
    invitations = OrganizationPagedList(name: "invitations", isLoading: scope.access.contains(.manageMemberships)) { _, offset in
      try await organization.getInvitations(offset: offset, pageSize: pageSize, status: ["pending"])
    }
    membershipRequests = OrganizationPagedList(
      name: "membership requests",
      isLoading: scope.access.contains(.manageMembershipRequests)
    ) { _, offset in
      try await organization.getMembershipRequests(offset: offset, pageSize: pageSize, status: "pending")
    }
    roles = OrganizationRolesDataSource(scope: scope)

    let reportError: @MainActor (Error) -> Void = { [weak self] error in
      self?.error = error
    }
    members.onError = reportError
    invitations.onError = reportError
    membershipRequests.onError = reportError
  }

  func start() {
    if !scope.access.isDisjoint(with: [.readMemberships, .manageMemberships]) {
      roles.start()
    }
    if scope.access.contains(.readMemberships) {
      members.reload(query: "")
    }
    if scope.access.contains(.manageMemberships) {
      invitations.reload()
    }
    if scope.access.contains(.manageMembershipRequests) {
      membershipRequests.reload()
    }
  }

  func retire() {
    members.retire()
    invitations.retire()
    membershipRequests.retire()
    roles.retire()
  }

  func refreshMembers() async {
    async let rolesLoad: Void = roles.refresh()
    async let membersLoad: Void = members.refresh()
    _ = await (rolesLoad, membersLoad)
  }

  func refreshInvitations() async {
    async let rolesLoad: Void = roles.refresh()
    async let invitationsLoad: Void = invitations.refresh()
    _ = await (rolesLoad, invitationsLoad)
  }

  func refreshMembershipRequests() async {
    await membershipRequests.refresh()
  }

  func searchMembers(query: String) {
    guard scope.access.contains(.readMemberships) else { return }
    guard query != members.query || (!members.isLoading && !members.hasLoaded) else { return }

    members.reload(query: query)
  }

  func invitationsSent() async {
    guard scope.access.contains(.manageMemberships) else { return }
    await invitations.reload().value
  }

  func updateMemberRole(_ membership: OrganizationMembership, role: RoleResource) async {
    guard role.key != membership.role, !roles.hasRoleSetMigration else { return }

    do {
      try await members.mutate(membership, as: .updating) {
        try await .replace(membership.update(role: role.key))
      }
    } catch {
      self.error = error
      ClerkLogger.error("Failed to update organization member role", error: error)
    }
  }

  func removeMember(_ membership: OrganizationMembership) async {
    do {
      try await members.mutate(membership, as: .removing) {
        try await membership.destroy()
        return .remove(membership)
      }
    } catch {
      self.error = error
      ClerkLogger.error("Failed to remove organization member", error: error)
    }
  }

  func revokeInvitation(_ invitation: OrganizationInvitation) async {
    do {
      try await invitations.mutate(invitation, as: .removing) {
        try await invitation.revoke()
        return .reload
      }
    } catch {
      self.error = error
      ClerkLogger.error("Failed to revoke organization invitation", error: error)
    }
  }

  func acceptMembershipRequest(_ request: OrganizationMembershipRequest) async {
    do {
      try await membershipRequests.mutate(request, as: .accepting) {
        try await request.accept()
        return .reload
      }
    } catch {
      self.error = error
      ClerkLogger.error("Failed to accept organization membership request", error: error)
      return
    }

    if scope.access.contains(.readMemberships), let query = members.query {
      await members.reload(query: query).value
    }
  }

  func rejectMembershipRequest(_ request: OrganizationMembershipRequest) async {
    do {
      try await membershipRequests.mutate(request, as: .rejecting) {
        try await request.reject()
        return .reload
      }
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

  private func roleName(for roleKey: String, fallback: String? = nil) -> String {
    if let role = roles.roles.first(where: { $0.key == roleKey }) {
      return role.name
    }

    if let fallback, !fallback.isEmpty {
      return fallback
    }

    return roleKey
  }
}

#endif
