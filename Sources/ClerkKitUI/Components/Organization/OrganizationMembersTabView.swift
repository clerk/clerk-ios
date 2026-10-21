//
//  OrganizationMembersTabView.swift
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct OrganizationMembersTabView: View {
  @Environment(\.clerkTheme) private var theme

  let dataSource: OrganizationMembersDataSource

  @State private var searchDebounceTask: Task<Void, Never>?

  private var canManageMemberships: Bool {
    dataSource.scope.access.contains(.manageMemberships)
  }

  var body: some View {
    VStack(spacing: 0) {
      controls

      OrganizationAccountPaginatedList(
        pager: dataSource.members.pager,
        isLoading: dataSource.members.isLoading,
        emptyState: {
          ClerkEmptyStateView(
            icon: .system("magnifyingglass"),
            title: "No members found",
            subtitle: "No members match your search. Try a different name or email address."
          )
        },
        onRefresh: refresh,
        onLoadMore: loadMore
      ) { membership in
        OrganizationMemberRow(
          membership: membership,
          roleName: dataSource.roleName(for: membership),
          roles: dataSource.roles.roles,
          isCurrentUser: membership.publicUserData?.userId == dataSource.scope.userID,
          canManageMemberships: canManageMemberships,
          hasRoleSetMigration: dataSource.roles.hasRoleSetMigration,
          isMutating: dataSource.members.mutations[membership.id] != nil,
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
    .onAppear {
      search()
    }
    .onDisappear {
      searchDebounceTask?.cancel()
    }
  }

  private var controls: some View {
    VStack(spacing: 12) {
      searchField

      if dataSource.roles.hasRoleSetMigration {
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
      #if os(iOS)
      .textInputAutocapitalization(.never)
      #endif
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
    await dataSource.refreshMembers()
  }

  @MainActor
  private func loadMore() async {
    dataSource.members.loadMore()
  }

  @MainActor
  private func removeMember(_ membership: OrganizationMembership) async {
    guard membership.publicUserData?.userId != dataSource.scope.userID else { return }
    await dataSource.removeMember(membership)
  }

  private func submitSearch() {
    searchDebounceTask?.cancel()
    search()
  }

  private func scheduleSearch(_ value: String) {
    searchDebounceTask?.cancel()

    let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmedValue.isEmpty {
      search(query: "")
      return
    }

    searchDebounceTask = Task { [trimmedValue] in
      do {
        try await Task.sleep(for: .milliseconds(500))
      } catch {
        return
      }

      guard !Task.isCancelled else { return }
      search(query: trimmedValue)
    }
  }

  @MainActor
  private func search(query: String? = nil) {
    let query = query ?? dataSource.membershipSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    dataSource.searchMembers(query: query)
  }
}

#endif
