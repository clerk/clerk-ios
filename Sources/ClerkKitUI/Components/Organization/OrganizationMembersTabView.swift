//
//  OrganizationMembersTabView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct OrganizationMembersTabView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  let dataSource: OrganizationMembersDataSource

  @State private var searchDebounceTask: Task<Void, Never>?

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

  var body: some View {
    VStack(spacing: 0) {
      controls

      OrganizationAccountPaginatedList(
        pager: dataSource.membershipsPager,
        isLoading: dataSource.isLoadingMembers,
        onRefresh: refresh,
        onLoadMore: loadMore
      ) { membership in
        OrganizationMemberRow(
          membership: membership,
          roleName: dataSource.roleName(for: membership),
          roles: dataSource.roles,
          isCurrentUser: membership.publicUserData?.userId == clerk.user?.id,
          canManageMemberships: canManageMemberships,
          hasRoleSetMigration: dataSource.hasRoleSetMigration,
          isMutating: dataSource.mutatingMembershipIds.contains(membership.id),
          onUpdateRole: { role in
            await dataSource.updateMemberRole(membership, role: role)
          },
          onRemove: {
            await removeMember(membership)
          }
        )
      }
    }
    .onChange(of: dataSource.membershipSearchText) { _, newValue in
      scheduleSearch(newValue)
    }
    .onDisappear {
      searchDebounceTask?.cancel()
    }
  }

  private var controls: some View {
    VStack(spacing: 12) {
      searchField

      if dataSource.hasRoleSetMigration {
        WarningText("We are updating the available roles. Once that's done, you'll be able to update roles again.", bundle: .module)
      }
    }
    .padding(.horizontal, 16)
    .padding(.top, 12)
    .padding(.bottom, 12)
  }

  private var searchField: some View {
    @Bindable var dataSource = dataSource

    return HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .font(theme.fonts.body)
        .foregroundStyle(theme.colors.mutedForeground)

      TextField(text: $dataSource.membershipSearchText) {
        Text("Search", bundle: .module)
          .foregroundStyle(theme.colors.mutedForeground)
      }
      .font(theme.fonts.body)
      .foregroundStyle(theme.colors.foreground)
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
      .submitLabel(.search)
      .onSubmit {
        submitSearch()
      }
    }
    .padding(.horizontal, 12)
    .frame(height: 36)
    .background(theme.colors.input)
    .clipShape(.rect(cornerRadius: theme.design.borderRadius))
    .overlay {
      RoundedRectangle(cornerRadius: theme.design.borderRadius)
        .strokeBorder(theme.colors.inputBorder, lineWidth: 1)
    }
  }
}

// MARK: - Actions

extension OrganizationMembersTabView {
  @MainActor
  private func refresh() async {
    guard canReadMemberships, let organization else { return }
    await dataSource.refreshMembers(organization: organization)
  }

  @MainActor
  private func loadMore() async {
    guard canReadMemberships, let organization else { return }
    await dataSource.loadMoreMembers(organization: organization)
  }

  @MainActor
  private func removeMember(_ membership: OrganizationMembership) async {
    guard membership.publicUserData?.userId != clerk.user?.id else { return }
    await dataSource.removeMember(membership)
  }

  private func submitSearch() {
    searchDebounceTask?.cancel()
    searchDebounceTask = Task { await search() }
  }

  private func scheduleSearch(_ value: String) {
    searchDebounceTask?.cancel()

    let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmedValue.isEmpty {
      searchDebounceTask = Task { await search(query: "") }
      return
    }

    searchDebounceTask = Task { [trimmedValue] in
      do {
        try await Task.sleep(for: .milliseconds(500))
      } catch {
        return
      }

      guard !Task.isCancelled else { return }
      await search(query: trimmedValue)
    }
  }

  @MainActor
  private func search(query: String? = nil) async {
    guard canReadMemberships, let organization else { return }

    let query = query ?? dataSource.membershipSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    await dataSource.searchMembers(organization: organization, query: query)
  }
}

#endif
