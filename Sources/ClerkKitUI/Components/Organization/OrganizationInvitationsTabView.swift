//
//  OrganizationInvitationsTabView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct OrganizationInvitationsTabView: View {
  @Environment(Clerk.self) private var clerk

  let dataSource: OrganizationMembersDataSource

  private var organization: Organization? {
    clerk.organization
  }

  private var organizationMembership: OrganizationMembership? {
    clerk.organizationMembership
  }

  private var canManageMemberships: Bool {
    organizationMembership?.canManageMemberships == true
  }

  var body: some View {
    OrganizationAccountPaginatedList(
      pager: dataSource.invitationsPager,
      isLoading: dataSource.isLoadingInvitations,
      emptyState: {
        ClerkEmptyStateView(
          icon: .asset("icon-invitation"),
          title: "No invitations sent",
          subtitle: "Get started by inviting someone to join your organization"
        )
      },
      onRefresh: refresh,
      onLoadMore: loadMore
    ) { invitation in
      OrganizationInvitationRow(
        invitation: invitation,
        roleName: dataSource.roleName(for: invitation),
        isRevoking: dataSource.revokingInvitationIds.contains(invitation.id),
        onRevoke: {
          await revokeInvitation(invitation)
        }
      )
    }
  }
}

// MARK: - Actions

extension OrganizationInvitationsTabView {
  @MainActor
  private func refresh() async {
    guard canManageMemberships, let organization else { return }
    await dataSource.refreshInvitations(organization: organization)
  }

  @MainActor
  private func loadMore() async {
    guard canManageMemberships, let organization else { return }
    await dataSource.loadMoreInvitations(organization: organization)
  }

  @MainActor
  private func revokeInvitation(_ invitation: OrganizationInvitation) async {
    guard canManageMemberships, let organization else { return }
    await dataSource.revokeInvitation(invitation, organization: organization)
  }
}

#endif
