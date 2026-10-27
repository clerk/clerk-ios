//
//  OrganizationInvitationsTabView.swift
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct OrganizationInvitationsTabView: View {
  let dataSource: OrganizationMembersDataSource

  var body: some View {
    OrganizationAccountPaginatedList(
      pager: dataSource.invitations.pager,
      isLoading: dataSource.invitations.isLoading,
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
        isRevoking: dataSource.invitations.mutations[invitation.id] != nil,
        onRevoke: {
          await dataSource.revokeInvitation(invitation)
        }
      )
    }
  }
}

// MARK: - Actions

extension OrganizationInvitationsTabView {
  @MainActor
  private func refresh() async {
    await dataSource.refreshInvitations()
  }

  @MainActor
  private func loadMore() async {
    dataSource.invitations.loadMore()
  }
}

#endif
