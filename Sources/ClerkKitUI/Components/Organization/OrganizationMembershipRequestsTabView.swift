//
//  OrganizationMembershipRequestsTabView.swift
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct OrganizationMembershipRequestsTabView: View {
  let dataSource: OrganizationMembersDataSource

  var body: some View {
    OrganizationAccountPaginatedList(
      pager: dataSource.membershipRequests.pager,
      isLoading: dataSource.membershipRequests.isLoading,
      emptyState: {
        ClerkEmptyStateView(
          icon: .asset("icon-users"),
          title: "No membership requests",
          subtitle: "Users who request to join your organization will appear here for review"
        )
      },
      onRefresh: refresh,
      onLoadMore: loadMore
    ) { request in
      let mutation = dataSource.membershipRequests.mutations[request.id]

      OrganizationMembershipRequestRow(
        request: request,
        isAccepting: mutation == .accepting,
        isRejecting: mutation == .rejecting,
        onAccept: {
          await dataSource.acceptMembershipRequest(request)
        },
        onReject: {
          await dataSource.rejectMembershipRequest(request)
        }
      )
    }
  }
}

// MARK: - Actions

extension OrganizationMembershipRequestsTabView {
  @MainActor
  private func refresh() async {
    await dataSource.refreshMembershipRequests()
  }

  @MainActor
  private func loadMore() async {
    dataSource.membershipRequests.loadMore()
  }
}

#endif
