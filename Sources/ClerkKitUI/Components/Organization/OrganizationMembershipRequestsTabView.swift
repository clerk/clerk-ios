//
//  OrganizationMembershipRequestsTabView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct OrganizationMembershipRequestsTabView: View {
  @Environment(Clerk.self) private var clerk

  let dataSource: OrganizationMembersDataSource

  private var organization: Organization? {
    clerk.organization
  }

  private var organizationMembership: OrganizationMembership? {
    clerk.organizationMembership
  }

  private var canReadMemberships: Bool {
    organizationMembership?.canReadMemberships == true
  }

  private var canManageMemberships: Bool {
    organizationMembership?.canManageMemberships == true
  }

  private var canManageMembershipRequests: Bool {
    canManageMemberships && clerk.environment?.organizationSettings.domains.enabled == true
  }

  var body: some View {
    OrganizationAccountPaginatedList(
      pager: dataSource.membershipRequestsPager,
      isLoading: dataSource.isLoadingMembershipRequests,
      emptyState: {
        ClerkEmptyStateView(
          icon: "icon-users",
          title: "No membership requests",
          subtitle: "Users who request to join your organization will appear here for review"
        )
      },
      onRefresh: refresh,
      onLoadMore: loadMore
    ) { request in
      let isAccepting = dataSource.acceptingMembershipRequestIds.contains(request.id)
      let isRejecting = dataSource.rejectingMembershipRequestIds.contains(request.id)

      OrganizationMembershipRequestRow(
        request: request,
        isAccepting: isAccepting,
        isRejecting: isRejecting,
        onAccept: {
          await acceptMembershipRequest(request)
        },
        onReject: {
          await rejectMembershipRequest(request)
        }
      )
    }
  }
}

// MARK: - Actions

extension OrganizationMembershipRequestsTabView {
  @MainActor
  private func refresh() async {
    guard canManageMembershipRequests, let organization else { return }
    await dataSource.loadMembershipRequests(organization: organization)
  }

  @MainActor
  private func loadMore() async {
    guard canManageMembershipRequests, let organization else { return }
    await dataSource.loadMoreMembershipRequests(organization: organization)
  }

  @MainActor
  private func acceptMembershipRequest(_ request: OrganizationMembershipRequest) async {
    guard canManageMembershipRequests, let organization else { return }
    await dataSource.acceptMembershipRequest(
      request,
      organization: organization,
      reloadMembers: canReadMemberships
    )
  }

  @MainActor
  private func rejectMembershipRequest(_ request: OrganizationMembershipRequest) async {
    guard canManageMembershipRequests, let organization else { return }
    await dataSource.rejectMembershipRequest(request, organization: organization)
  }
}

#endif
