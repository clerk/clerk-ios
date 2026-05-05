//
//  OrganizationMembersView.swift
//

#if os(iOS)

import ClerkKit
import NukeUI
import SwiftUI

struct OrganizationMembersView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  @State private var selectedTab: OrganizationMembersTab = .members
  @State private var searchText = ""
  @State private var searchQuery = ""
  @State private var searchDebounceTask: Task<Void, Never>?
  @State private var membershipsPager = OrganizationAccountListPager<OrganizationMembership>()
  @State private var invitationsPager = OrganizationAccountListPager<OrganizationInvitation>()
  @State private var membershipRequestsPager = OrganizationAccountListPager<OrganizationMembershipRequest>()
  @State private var isLoadingMembers = true
  @State private var isLoadingInvitations = true
  @State private var isLoadingMembershipRequests = true
  @State private var roles: [RoleResource] = []
  @State private var hasRoleSetMigration = false
  @State private var mutatingMembershipIds: Set<String> = []
  @State private var revokingInvitationIds: Set<String> = []
  @State private var acceptingMembershipRequestIds: Set<String> = []
  @State private var rejectingMembershipRequestIds: Set<String> = []
  @State private var inviteMembersIsPresented = false
  @State private var error: Error?

  private let pageSize = 10

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

  private var availableTabs: [OrganizationMembersTab] {
    var tabs: [OrganizationMembersTab] = []
    if canReadMemberships {
      tabs.append(.members)
    }
    if canManageMemberships {
      tabs.append(.invitations)
    }
    if canManageMembershipRequests {
      tabs.append(.requests)
    }
    return tabs
  }

  private var canInviteMembers: Bool {
    guard let organization else { return false }
    if organization.maxAllowedMemberships == 0 {
      return true
    }

    let membersCount = organization.membersCount ?? 0
    let pendingInvitationsCount = organization.pendingInvitationsCount ?? 0
    return membersCount + pendingInvitationsCount < organization.maxAllowedMemberships
  }

  var body: some View {
    VStack(spacing: 0) {
      if !availableTabs.isEmpty {
        controls
      }

      membersContent
    }
    .background(theme.colors.muted)
    .navigationBarTitleDisplayMode(.inline)
    .preGlassSolidNavBar()
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text("Members", bundle: .module)
          .font(theme.fonts.headline)
          .fontWeight(.semibold)
          .foregroundStyle(theme.colors.foreground)
      }

      if canManageMemberships {
        ToolbarItem(placement: .primaryAction) {
          Button {
            inviteMembersIsPresented = true
          } label: {
            Text("Invite", bundle: .module)
          }
          .disabled(!canInviteMembers)
        }
      }
    }
    .sheet(isPresented: $inviteMembersIsPresented) {
      OrganizationInviteMembersView(roles: roles) {
        await loadInvitations(page: 1)
      }
    }
    .clerkErrorPresenting($error)
    .task(id: organization?.id) {
      await loadInitialData()
    }
    .onChange(of: searchText) { _, newValue in
      scheduleSearch(newValue)
    }
    .onDisappear {
      searchDebounceTask?.cancel()
    }
  }
}

// MARK: - Subviews

extension OrganizationMembersView {
  private var controls: some View {
    VStack(spacing: 12) {
      if availableTabs.count > 1 {
        Picker("", selection: $selectedTab) {
          ForEach(availableTabs) { tab in
            Text(tab.title, bundle: .module)
              .tag(tab)
          }
        }
        .pickerStyle(.segmented)
      }

      if selectedTab == .members {
        searchField

        if hasRoleSetMigration {
          WarningText("We are updating the available roles. Once that's done, you'll be able to update roles again.", bundle: .module)
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.top, 12)
    .padding(.bottom, 12)
  }

  private var searchField: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .font(theme.fonts.body)
        .foregroundStyle(theme.colors.mutedForeground)

      TextField(text: $searchText) {
        Text("Search", bundle: .module)
          .foregroundStyle(theme.colors.mutedForeground)
      }
      .font(theme.fonts.body)
      .foregroundStyle(theme.colors.foreground)
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
      .submitLabel(.search)
      .onSubmit {
        searchDebounceTask?.cancel()
        searchQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        searchDebounceTask = Task { await loadMembers(page: 1) }
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

  @ViewBuilder
  private var membersContent: some View {
    switch selectedTab {
    case .members:
      membersList
    case .invitations:
      invitationsList
    case .requests:
      requestsList
    }
  }

  private var membersList: some View {
    OrganizationAccountPaginatedList(
      pager: membershipsPager,
      isLoading: isLoadingMembers,
      emptyText: "No members found",
      onRefresh: loadInitialData,
      onLoadMore: loadMoreMembers
    ) { membership in
      OrganizationMemberRow(
        membership: membership,
        roleName: roleName(for: membership),
        roles: roles,
        isCurrentUser: membership.publicUserData?.userId == clerk.user?.id,
        canManageMemberships: canManageMemberships,
        hasRoleSetMigration: hasRoleSetMigration,
        isMutating: mutatingMembershipIds.contains(membership.id),
        onUpdateRole: { role in
          await updateMemberRole(membership, role: role)
        },
        onRemove: {
          await removeMember(membership)
        }
      )
    }
  }

  private var invitationsList: some View {
    OrganizationAccountPaginatedList(
      pager: invitationsPager,
      isLoading: isLoadingInvitations,
      emptyText: "No pending invitations",
      onRefresh: loadInitialData,
      onLoadMore: loadMoreInvitations
    ) { invitation in
      OrganizationInvitationRow(
        invitation: invitation,
        roleName: roleName(for: invitation),
        isRevoking: revokingInvitationIds.contains(invitation.id),
        onRevoke: {
          await revokeInvitation(invitation)
        }
      )
    }
  }

  private var requestsList: some View {
    OrganizationAccountPaginatedList(
      pager: membershipRequestsPager,
      isLoading: isLoadingMembershipRequests,
      emptyText: "No pending requests",
      onRefresh: loadInitialData,
      onLoadMore: loadMoreMembershipRequests
    ) { request in
      let isAccepting = acceptingMembershipRequestIds.contains(request.id)
      let isRejecting = rejectingMembershipRequestIds.contains(request.id)

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

private struct OrganizationAccountPaginatedList<Item: Identifiable & Codable & Sendable, Row: View>: View {
  @Environment(\.clerkTheme) private var theme

  let pager: OrganizationAccountListPager<Item>
  let isLoading: Bool
  let emptyText: LocalizedStringKey
  let onRefresh: () async -> Void
  let onLoadMore: () async -> Void
  let row: (Item) -> Row

  init(
    pager: OrganizationAccountListPager<Item>,
    isLoading: Bool,
    emptyText: LocalizedStringKey,
    onRefresh: @escaping () async -> Void,
    onLoadMore: @escaping () async -> Void,
    @ViewBuilder row: @escaping (Item) -> Row
  ) {
    self.pager = pager
    self.isLoading = isLoading
    self.emptyText = emptyText
    self.onRefresh = onRefresh
    self.onLoadMore = onLoadMore
    self.row = row
  }

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        Divider()

        if isLoading, pager.items.isEmpty {
          SpinnerView()
            .frame(width: 24, height: 24)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else if pager.items.isEmpty {
          Text(emptyText, bundle: .module)
            .font(theme.fonts.body)
            .foregroundStyle(theme.colors.mutedForeground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else {
          OrganizationPaginatedListSection(
            items: pager.items,
            hasNextPage: pager.hasNextPage,
            onLoadMore: onLoadMore,
            content: row
          )

          if pager.isLoadingMore {
            SpinnerView()
              .frame(width: 24, height: 24)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 16)
          }
        }
      }
    }
    .refreshable {
      await onRefresh()
    }
  }
}

private struct OrganizationInviteMembersView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss

  let roles: [RoleResource]
  let onSuccess: () async -> Void

  @State private var emailAddressText = ""
  @State private var selectedRoleKey = ""
  @State private var error: Error?
  @FocusState private var emailFieldIsFocused: Bool

  private var roleOptions: [RoleResource] {
    roles
  }

  private var emailAddresses: [String] {
    emailAddressText
      .components(separatedBy: CharacterSet(charactersIn: ",;\n\t "))
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  private var invalidEmailAddresses: [String] {
    emailAddresses.filter { !isValidEmailAddress($0) }
  }

  private var fieldError: ClerkClientError? {
    guard !emailAddressText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return nil
    }

    if emailAddresses.isEmpty {
      return ClerkClientError(message: "Enter at least one email address.")
    }

    if !invalidEmailAddresses.isEmpty {
      return ClerkClientError(message: "Enter valid email addresses.")
    }

    return nil
  }

  private var canSubmit: Bool {
    !emailAddresses.isEmpty && invalidEmailAddresses.isEmpty && roleOptions.contains { $0.key == selectedRoleKey }
  }

  private var submitTitle: LocalizedStringKey {
    emailAddresses.count == 1 ? "Send invitation" : "Send invitations"
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          emailField
          rolePicker

          if let error {
            ErrorText(error: error, alignment: .leading)
              .font(theme.fonts.subheadline)
              .transition(.blurReplace.animation(.default))
              .id(error.localizedDescription)
          }

          AsyncButton {
            await submit()
          } label: { isRunning in
            Text(submitTitle, bundle: .module)
              .frame(maxWidth: .infinity)
              .overlayProgressView(isActive: isRunning) {
                SpinnerView(color: theme.colors.primaryForeground)
              }
          }
          .buttonStyle(.primary())
          .disabled(!canSubmit)
        }
        .padding(24)
      }
      .presentationBackground(theme.colors.background)
      .navigationBarTitleDisplayMode(.inline)
      .preGlassSolidNavBar()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
          .foregroundStyle(theme.colors.primary)
        }

        ToolbarItem(placement: .principal) {
          Text("Invite members", bundle: .module)
            .font(theme.fonts.headline)
            .foregroundStyle(theme.colors.foreground)
        }
      }
    }
    .onChange(of: emailAddressText) { _, _ in
      error = nil
    }
    .onChange(of: selectedRoleKey) { _, _ in
      error = nil
    }
    .onChange(of: roles.map(\.key), initial: true) { _, _ in
      selectDefaultRoleIfNeeded()
    }
  }

  private var emailField: some View {
    VStack(alignment: .leading, spacing: 8) {
      ClerkTextField(
        "Email addresses",
        text: $emailAddressText,
        fieldState: fieldError == nil ? .default : .error
      )
      .textContentType(.emailAddress)
      .keyboardType(.emailAddress)
      .autocorrectionDisabled()
      .textInputAutocapitalization(.never)
      .focused($emailFieldIsFocused)
      .onFirstAppear {
        emailFieldIsFocused = true
      }

      if let fieldError {
        ErrorText(error: fieldError, alignment: .leading)
          .font(theme.fonts.subheadline)
          .transition(.blurReplace.animation(.default))
          .id(fieldError.localizedDescription)
      }
    }
  }

  private var rolePicker: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 12) {
        Text("Role", bundle: .module)
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.foreground)

        Spacer()

        Picker("Role", selection: $selectedRoleKey) {
          ForEach(roleOptions) { role in
            Text(verbatim: role.name)
              .tag(role.key)
          }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .tint(theme.colors.primary)
        .disabled(roleOptions.isEmpty)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 6)
      .frame(minHeight: 56)
      .background(
        theme.colors.input,
        in: .rect(cornerRadius: theme.design.borderRadius)
      )
      .clerkFocusedBorder(isFocused: false)

      if roleOptions.isEmpty {
        Text("No roles available", bundle: .module)
          .font(theme.fonts.subheadline)
          .foregroundStyle(theme.colors.mutedForeground)
      }
    }
  }

  @MainActor
  private func submit() async {
    error = nil

    guard canSubmit else { return }
    guard let organization = clerk.organization else {
      error = ClerkClientError(message: "Unable to send invitations without an active organization.")
      return
    }

    do {
      try await organization.inviteMembers(emailAddresses: emailAddresses, role: selectedRoleKey)
      await onSuccess()
      dismiss()
    } catch {
      self.error = error
    }
  }

  private func selectDefaultRoleIfNeeded() {
    guard selectedRoleKey.isEmpty else { return }

    let defaultRoleKey = clerk.environment?.organizationSettings.domains.defaultRole
    if let defaultRoleKey, roleOptions.contains(where: { $0.key == defaultRoleKey }) {
      selectedRoleKey = defaultRoleKey
    } else if roleOptions.count == 1, let role = roleOptions.first {
      selectedRoleKey = role.key
    }
  }

  private func isValidEmailAddress(_ emailAddress: String) -> Bool {
    emailAddress.range(of: #"^\S+@\S+\.\S+$"#, options: .regularExpression) != nil
  }
}

// MARK: - Actions

extension OrganizationMembersView {
  @MainActor
  private func loadInitialData() async {
    if let firstAvailableTab = availableTabs.first, !availableTabs.contains(selectedTab) {
      selectedTab = firstAvailableTab
    }

    guard canReadMemberships || canManageMemberships else {
      isLoadingMembers = false
      isLoadingInvitations = false
      isLoadingMembershipRequests = false
      membershipsPager = OrganizationAccountListPager()
      invitationsPager = OrganizationAccountListPager()
      membershipRequestsPager = OrganizationAccountListPager()
      return
    }

    await loadRoles()

    if canReadMemberships {
      await loadMembers(page: 1)
    } else {
      isLoadingMembers = false
      membershipsPager = OrganizationAccountListPager()
    }

    if canManageMemberships {
      await loadInvitations(page: 1)
    } else {
      isLoadingInvitations = false
      invitationsPager = OrganizationAccountListPager()
    }

    if canManageMembershipRequests {
      await loadMembershipRequests(page: 1)
    } else {
      isLoadingMembershipRequests = false
      membershipRequestsPager = OrganizationAccountListPager()
    }
  }

  @MainActor
  private func loadRoles() async {
    guard let organization else { return }

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

  @MainActor
  private func loadMembers(page: Int) async {
    guard let organization else { return }

    isLoadingMembers = true
    defer { isLoadingMembers = false }

    do {
      let page = try await organization.getMemberships(
        query: searchQuery.isEmpty ? nil : searchQuery,
        page: page,
        pageSize: pageSize
      )
      membershipsPager.replace(with: page)
    } catch {
      guard !error.isCancellationError else { return }

      self.error = error
      ClerkLogger.error("Failed to load organization members", error: error)
    }
  }

  @MainActor
  private func loadMoreMembers() async {
    guard let organization, !membershipsPager.isLoadingMore, membershipsPager.hasNextPage else { return }

    membershipsPager.isLoadingMore = true
    defer { membershipsPager.isLoadingMore = false }

    do {
      let page = try await organization.getMemberships(
        query: searchQuery.isEmpty ? nil : searchQuery,
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

  @MainActor
  private func loadInvitations(page: Int) async {
    guard let organization else { return }

    isLoadingInvitations = true
    defer { isLoadingInvitations = false }

    do {
      let page = try await organization.getInvitations(page: page, pageSize: pageSize, status: "pending")
      invitationsPager.replace(with: page)
    } catch {
      guard !error.isCancellationError else { return }

      self.error = error
      ClerkLogger.error("Failed to load organization invitations", error: error)
    }
  }

  @MainActor
  private func loadMoreInvitations() async {
    guard let organization, !invitationsPager.isLoadingMore, invitationsPager.hasNextPage else { return }

    invitationsPager.isLoadingMore = true
    defer { invitationsPager.isLoadingMore = false }

    do {
      let page = try await organization.getInvitations(
        offset: invitationsPager.offset,
        pageSize: pageSize,
        status: "pending"
      )
      invitationsPager.append(page)
    } catch {
      guard !error.isCancellationError else { return }

      self.error = error
      ClerkLogger.error("Failed to load more organization invitations", error: error)
    }
  }

  @MainActor
  private func loadMembershipRequests(page: Int) async {
    guard let organization else { return }

    isLoadingMembershipRequests = true
    defer { isLoadingMembershipRequests = false }

    do {
      let page = try await organization.getMembershipRequests(page: page, pageSize: pageSize, status: "pending")
      membershipRequestsPager.replace(with: page)
    } catch {
      guard !error.isCancellationError else { return }

      self.error = error
      ClerkLogger.error("Failed to load organization membership requests", error: error)
    }
  }

  @MainActor
  private func loadMoreMembershipRequests() async {
    guard let organization, !membershipRequestsPager.isLoadingMore, membershipRequestsPager.hasNextPage else { return }

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

  @MainActor
  private func updateMemberRole(_ membership: OrganizationMembership, role: RoleResource) async {
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

  @MainActor
  private func removeMember(_ membership: OrganizationMembership) async {
    guard membership.publicUserData?.userId != clerk.user?.id else { return }
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

  @MainActor
  private func revokeInvitation(_ invitation: OrganizationInvitation) async {
    guard !revokingInvitationIds.contains(invitation.id) else { return }

    revokingInvitationIds.insert(invitation.id)
    defer { revokingInvitationIds.remove(invitation.id) }

    do {
      try await invitation.revoke()
      await loadInvitations(page: 1)
    } catch {
      self.error = error
      ClerkLogger.error("Failed to revoke organization invitation", error: error)
    }
  }

  @MainActor
  private func acceptMembershipRequest(_ request: OrganizationMembershipRequest) async {
    guard !acceptingMembershipRequestIds.contains(request.id),
          !rejectingMembershipRequestIds.contains(request.id)
    else { return }

    acceptingMembershipRequestIds.insert(request.id)
    defer { acceptingMembershipRequestIds.remove(request.id) }

    do {
      try await request.accept()
      await loadMembershipRequests(page: 1)
      if canReadMemberships {
        await loadMembers(page: 1)
      }
    } catch {
      self.error = error
      ClerkLogger.error("Failed to accept organization membership request", error: error)
    }
  }

  @MainActor
  private func rejectMembershipRequest(_ request: OrganizationMembershipRequest) async {
    guard !acceptingMembershipRequestIds.contains(request.id),
          !rejectingMembershipRequestIds.contains(request.id)
    else { return }

    rejectingMembershipRequestIds.insert(request.id)
    defer { rejectingMembershipRequestIds.remove(request.id) }

    do {
      try await request.reject()
      await loadMembershipRequests(page: 1)
    } catch {
      self.error = error
      ClerkLogger.error("Failed to reject organization membership request", error: error)
    }
  }

  private func scheduleSearch(_ value: String) {
    searchDebounceTask?.cancel()

    let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmedValue.isEmpty {
      searchQuery = ""
      searchDebounceTask = Task { await loadMembers(page: 1) }
      return
    }

    searchDebounceTask = Task { [trimmedValue] in
      do {
        try await Task.sleep(for: .milliseconds(500))
      } catch {
        return
      }

      guard !Task.isCancelled else { return }
      await MainActor.run {
        searchQuery = trimmedValue
      }
      await loadMembers(page: 1)
    }
  }

  private func roleName(for membership: OrganizationMembership) -> String {
    roleName(for: membership.role, fallback: membership.roleName)
  }

  private func roleName(for invitation: OrganizationInvitation) -> String {
    roleName(for: invitation.role)
  }

  private func roleName(for roleKey: String, fallback: String? = nil) -> String {
    if let role = roles.first(where: { $0.key == roleKey }) {
      return role.name
    }

    if let fallback, !fallback.isEmpty {
      return fallback
    }

    return roleKey
  }
}

// MARK: - Row

private struct OrganizationMemberRow: View {
  @Environment(\.clerkTheme) private var theme

  let membership: OrganizationMembership
  let roleName: String
  let roles: [RoleResource]
  let isCurrentUser: Bool
  let canManageMemberships: Bool
  let hasRoleSetMigration: Bool
  let isMutating: Bool
  let onUpdateRole: (RoleResource) async -> Void
  let onRemove: () async -> Void

  private var publicUserData: PublicUserData? {
    membership.publicUserData
  }

  private var displayName: String? {
    publicUserData?.displayName
  }

  private var identifier: String? {
    publicUserData?.identifier
  }

  private var joinedDate: String {
    membership.createdAt.formatted(.dateTime.month(.defaultDigits).day(.defaultDigits).year())
  }

  private var roleMenuIsDisabled: Bool {
    roles.isEmpty || hasRoleSetMigration || isMutating
  }

  var body: some View {
    HStack(alignment: .center, spacing: 16) {
      HStack(alignment: .top, spacing: 16) {
        OrganizationMemberAvatarView(userData: publicUserData)

        VStack(alignment: .leading, spacing: 4) {
          if isCurrentUser {
            Text("You", bundle: .module)
              .font(theme.fonts.footnote)
              .foregroundStyle(theme.colors.mutedForeground)
              .padding(.horizontal, 6)
              .frame(height: 18)
              .background(theme.colors.background)
              .clipShape(.rect(cornerRadius: theme.design.borderRadius))
              .overlay {
                RoundedRectangle(cornerRadius: theme.design.borderRadius)
                  .strokeBorder(theme.colors.buttonBorder, lineWidth: 1)
              }
          }

          if let displayName {
            Text(verbatim: displayName)
              .font(theme.fonts.body)
              .foregroundStyle(theme.colors.foreground)
              .lineLimit(1)
          }

          if let identifier, !identifier.isEmpty {
            Text(verbatim: identifier)
              .font(theme.fonts.subheadline)
              .foregroundStyle(theme.colors.mutedForeground)
              .lineLimit(1)
          }

          if isCurrentUser {
            Text(verbatim: "\(roleName) · Joined \(joinedDate)")
              .font(theme.fonts.footnote)
              .foregroundStyle(theme.colors.mutedForeground)
              .lineLimit(1)
          } else {
            Text(verbatim: roleName)
              .font(theme.fonts.subheadline)
              .foregroundStyle(theme.colors.mutedForeground)
              .lineLimit(1)
            Text(verbatim: "Joined \(joinedDate)")
              .font(theme.fonts.subheadline)
              .foregroundStyle(theme.colors.mutedForeground)
              .lineLimit(1)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      if canManageMemberships {
        memberMenu
      }
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
    .background(theme.colors.background)
  }

  private var memberMenu: some View {
    Menu {
      Menu {
        ForEach(roles) { role in
          AsyncButton {
            await onUpdateRole(role)
          } label: { _ in
            Label {
              Text(verbatim: role.name)
            } icon: {
              if role.key == membership.role {
                Image(systemName: "checkmark")
              }
            }
          }
          .disabled(role.key == membership.role || isMutating)
        }
      } label: {
        Text("Change role", bundle: .module)
      }
      .disabled(roleMenuIsDisabled)

      AsyncButton(role: .destructive) {
        await onRemove()
      } label: { _ in
        Text("Remove member", bundle: .module)
      }
      .disabled(isCurrentUser || isMutating)
    } label: {
      Image("icon-three-dots-vertical", bundle: .module)
        .resizable()
        .scaledToFit()
        .foregroundColor(theme.colors.mutedForeground)
        .frame(width: 20, height: 20)
        .accessibilityLabel(Text("Member actions", bundle: .module))
    }
    .frame(width: 30, height: 30)
  }
}

private struct OrganizationInvitationRow: View {
  @Environment(\.clerkTheme) private var theme

  let invitation: OrganizationInvitation
  let roleName: String
  let isRevoking: Bool
  let onRevoke: () async -> Void

  private var invitedDate: String {
    invitation.createdAt.formatted(.dateTime.month(.defaultDigits).day(.defaultDigits).year())
  }

  var body: some View {
    HStack(alignment: .center, spacing: 16) {
      HStack(alignment: .top, spacing: 16) {
        OrganizationInvitationAvatarView(emailAddress: invitation.emailAddress)

        VStack(alignment: .leading, spacing: 4) {
          Text(verbatim: invitation.emailAddress)
            .font(theme.fonts.body)
            .foregroundStyle(theme.colors.foreground)
            .lineLimit(1)

          Text(verbatim: roleName)
            .font(theme.fonts.subheadline)
            .foregroundStyle(theme.colors.mutedForeground)
            .lineLimit(1)

          Text(verbatim: "Invited \(invitedDate)")
            .font(theme.fonts.subheadline)
            .foregroundStyle(theme.colors.mutedForeground)
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      invitationMenu
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
    .background(theme.colors.background)
  }

  private var invitationMenu: some View {
    Menu {
      AsyncButton(role: .destructive) {
        await onRevoke()
      } label: { _ in
        Text("Revoke invitation", bundle: .module)
      }
      .disabled(isRevoking)
    } label: {
      Image("icon-three-dots-vertical", bundle: .module)
        .resizable()
        .scaledToFit()
        .foregroundColor(theme.colors.mutedForeground)
        .frame(width: 20, height: 20)
        .accessibilityLabel(Text("Invitation actions", bundle: .module))
    }
    .frame(width: 30, height: 30)
  }
}

private struct OrganizationMembershipRequestRow: View {
  @Environment(\.clerkTheme) private var theme

  let request: OrganizationMembershipRequest
  let isAccepting: Bool
  let isRejecting: Bool
  let onAccept: () async -> Void
  let onReject: () async -> Void

  private var publicUserData: PublicUserData? {
    request.publicUserData
  }

  private var displayName: String? {
    publicUserData?.displayName
  }

  private var identifier: String? {
    publicUserData?.identifier
  }

  private var requestedDate: String {
    request.createdAt.formatted(.dateTime.month(.defaultDigits).day(.defaultDigits).year())
  }

  var body: some View {
    HStack(alignment: .center, spacing: 16) {
      HStack(alignment: .top, spacing: 16) {
        OrganizationMemberAvatarView(userData: publicUserData)

        VStack(alignment: .leading, spacing: 4) {
          if let displayName {
            Text(verbatim: displayName)
              .font(theme.fonts.body)
              .foregroundStyle(theme.colors.foreground)
              .lineLimit(1)
          }

          if let identifier, !identifier.isEmpty {
            Text(verbatim: identifier)
              .font(theme.fonts.subheadline)
              .foregroundStyle(theme.colors.mutedForeground)
              .lineLimit(1)
          }

          Text(verbatim: "Requested \(requestedDate)")
            .font(theme.fonts.subheadline)
            .foregroundStyle(theme.colors.mutedForeground)
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      requestMenu
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
    .background(theme.colors.background)
  }

  private var requestMenu: some View {
    Menu {
      AsyncButton {
        await onAccept()
      } label: { _ in
        Text("Accept request", bundle: .module)
      }
      .disabled(isAccepting || isRejecting)

      AsyncButton(role: .destructive) {
        await onReject()
      } label: { _ in
        Text("Reject request", bundle: .module)
      }
      .disabled(isAccepting || isRejecting)
    } label: {
      Image("icon-three-dots-vertical", bundle: .module)
        .resizable()
        .scaledToFit()
        .foregroundColor(theme.colors.mutedForeground)
        .frame(width: 20, height: 20)
        .accessibilityLabel(Text("Request actions", bundle: .module))
    }
    .frame(width: 30, height: 30)
  }
}

private struct OrganizationMemberAvatarView: View {
  @Environment(\.clerkTheme) private var theme

  let userData: PublicUserData?

  private var initials: String {
    let source = userData?.displayName ?? userData?.identifier ?? ""
    let parts = source
      .split(separator: " ")
      .prefix(2)
      .compactMap(\.first)

    let initials = String(parts).uppercased()
    if !initials.isEmpty {
      return initials
    }

    return String(source.prefix(1)).uppercased()
  }

  var body: some View {
    LazyImage(url: URL(string: userData?.imageUrl ?? "")) { state in
      if let image = state.image {
        image
          .resizable()
          .scaledToFill()
      } else {
        initialsView
      }
    }
    .frame(width: 36, height: 36)
    .clipShape(.circle)
  }

  private var initialsView: some View {
    ZStack {
      Circle()
        .fill(theme.colors.primary.gradient)

      Text(verbatim: initials)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(theme.colors.primaryForeground)
    }
  }
}

private struct OrganizationInvitationAvatarView: View {
  @Environment(\.clerkTheme) private var theme

  let emailAddress: String

  private var initials: String {
    let localPart = emailAddress.split(separator: "@", maxSplits: 1).first.map(String.init) ?? emailAddress
    let parts = localPart
      .split { !$0.isLetter && !$0.isNumber }
      .prefix(2)
      .compactMap(\.first)

    let initials = String(parts).uppercased()
    if !initials.isEmpty {
      return initials
    }

    return String(emailAddress.prefix(1)).uppercased()
  }

  var body: some View {
    ZStack {
      Circle()
        .fill(theme.colors.primary.gradient)

      Text(verbatim: initials)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(theme.colors.primaryForeground)
    }
    .frame(width: 36, height: 36)
  }
}

// MARK: - Types

private enum OrganizationMembersTab: Hashable, Identifiable {
  case members
  case invitations
  case requests

  var id: Self {
    self
  }

  var title: LocalizedStringKey {
    switch self {
    case .members:
      "Members"
    case .invitations:
      "Invitations"
    case .requests:
      "Requests"
    }
  }
}

extension PublicUserData {
  fileprivate var displayName: String? {
    let name = [firstName, lastName]
      .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: " ")

    return name.isEmpty ? nil : name
  }
}

#Preview("Organization Members") {
  NavigationStack {
    OrganizationMembersView()
      .environment(Clerk.preview { preview in
        let organization = Organization.mock
        var membership = OrganizationMembership.mockWithUserData
        membership.organization = organization
        membership.permissions = [
          OrganizationSystemPermission.readMemberships.rawValue,
          OrganizationSystemPermission.manageMemberships.rawValue,
        ]

        var user = User.mock
        user.organizationMemberships = [membership]

        var session = Session.mock
        session.lastActiveOrganizationId = organization.id
        session.user = user

        var client = Client.mock
        client.sessions = [session]
        client.lastActiveSessionId = session.id

        preview.client = client
        var environment = Clerk.Environment.mock
        environment.organizationSettings.domains.enabled = true
        preview.environment = environment
      })
  }
}

#endif
