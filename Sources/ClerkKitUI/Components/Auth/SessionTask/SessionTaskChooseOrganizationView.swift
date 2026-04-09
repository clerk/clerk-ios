//
//  SessionTaskChooseOrganizationView.swift
//

#if os(iOS)

import ClerkKit
import NukeUI
import SwiftUI

/// A view shown when a session requires the user to choose or create an organization
/// before the session can become active.
struct SessionTaskChooseOrganizationView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation

  private let pageSize = 10

  @State private var membershipsPager = PagerState<OrganizationMembership>()
  @State private var invitationsPager = PagerState<UserOrganizationInvitation>()
  @State private var suggestionsPager = PagerState<OrganizationSuggestion>()
  @State private var acceptedInvitationOrgIds: Set<String> = []
  @State private var isLoading = true
  @State private var creationDefaults: OrganizationCreationDefaults?
  @State private var error: Error?

  private var user: User? {
    clerk.user
  }

  private var hasExistingResources: Bool {
    !membershipsPager.items.isEmpty || !invitationsPager.items.isEmpty || !suggestionsPager.items.isEmpty
  }

  private var isLoadingMore: Bool {
    membershipsPager.isLoadingMore || invitationsPager.isLoadingMore || suggestionsPager.isLoadingMore
  }

  private var hasNextPage: Bool {
    membershipsPager.hasNextPage || invitationsPager.hasNextPage || suggestionsPager.hasNextPage
  }

  var body: some View {
    Group {
      if !isLoading, !hasExistingResources, user?.createOrganizationEnabled == false {
        GetHelpView(context: .sessionTask(.organizationRequired))
          .navigationBarBackButtonHidden()
          .navigationBarTitleDisplayMode(.inline)
          .preGlassSolidNavBar()
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              UserButton(presentationContext: .sessionTaskToolbar)
            }
          }
      } else if !isLoading, !hasExistingResources {
        SessionTaskCreateOrganizationView(creationDefaults: creationDefaults)
      } else {
        Group {
          if isLoading {
            SpinnerView()
              .frame(width: 32, height: 32)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else {
            chooseOrganizationContent
          }
        }
        .background(theme.colors.background)
        .navigationBarBackButtonHidden()
        .navigationBarTitleDisplayMode(.inline)
        .preGlassSolidNavBar()
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            UserButton(presentationContext: .sessionTaskToolbar)
          }
        }
      }
    }
    .clerkErrorPresenting($error)
    .taskOnce {
      await fetchOrganizationResources()
    }
  }

  // MARK: - Choose Organization

  private var chooseOrganizationContent: some View {
    ScrollView {
      VStack(spacing: 32) {
        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Choose an Organization")
          if user?.createOrganizationEnabled == true {
            HeaderView(style: .subtitle, text: "Join an existing organization or create a new one")
          } else {
            HeaderView(style: .subtitle, text: "Join an existing organization")
          }
        }
        .padding(.horizontal, 16)

        LazyVStack(spacing: 0) {
          Divider()

          ForEach(membershipsPager.items) { membership in
            AsyncButton {
              await selectOrganization(id: membership.organization.id)
            } label: { _ in
              OrganizationRow(
                name: membership.organization.name,
                imageUrl: membership.organization.imageUrl,
                subtitle: membership.roleName
              )
            }
            .buttonStyle(.plain)
            .onAppear {
              if membership.id == membershipsPager.items.last?.id {
                Task { await loadMoreMemberships() }
              }
            }
            Divider()
          }

          if !membershipsPager.hasNextPage {
            ForEach(invitationsPager.items) { invitation in
              Group {
                if acceptedInvitationOrgIds.contains(invitation.publicOrganizationData.id) {
                  AsyncButton {
                    await selectOrganization(id: invitation.publicOrganizationData.id)
                  } label: { _ in
                    OrganizationRow(
                      name: invitation.publicOrganizationData.name,
                      imageUrl: invitation.publicOrganizationData.imageUrl,
                      subtitle: displayRoleName(for: invitation.role)
                    )
                  }
                  .buttonStyle(.plain)
                } else {
                  AsyncButton {
                    await acceptInvitation(invitation)
                  } label: { isRunning in
                    OrganizationRow(
                      name: invitation.publicOrganizationData.name,
                      imageUrl: invitation.publicOrganizationData.imageUrl
                    ) {
                      ActionLabel("Join", isLoading: isRunning)
                    }
                  }
                  .buttonStyle(.plain)
                }
              }
              .onAppear {
                if invitation.id == invitationsPager.items.last?.id {
                  Task { await loadMoreInvitations() }
                }
              }
              Divider()
            }
          }

          if !membershipsPager.hasNextPage, !invitationsPager.hasNextPage {
            ForEach(suggestionsPager.items) { suggestion in
              Group {
                if suggestion.status == "accepted" {
                  OrganizationRow(
                    name: suggestion.publicOrganizationData.name,
                    imageUrl: suggestion.publicOrganizationData.imageUrl,
                    subtitle: String(localized: "Pending approval", bundle: .module)
                  )
                } else {
                  AsyncButton {
                    await acceptSuggestion(suggestion)
                  } label: { isRunning in
                    OrganizationRow(
                      name: suggestion.publicOrganizationData.name,
                      imageUrl: suggestion.publicOrganizationData.imageUrl
                    ) {
                      ActionLabel("Request to join", isLoading: isRunning)
                    }
                  }
                  .buttonStyle(.plain)
                }
              }
              .onAppear {
                if suggestion.id == suggestionsPager.items.last?.id {
                  Task { await loadMoreSuggestions() }
                }
              }
              Divider()
            }
          }

          if isLoadingMore {
            SpinnerView()
              .frame(width: 24, height: 24)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 16)
          }

          if !hasNextPage, user?.createOrganizationEnabled == true {
            Button {
              navigation.path.append(.sessionTaskCreateOrganization(creationDefaults: creationDefaults))
            } label: {
              createOrganizationRow
            }
            .buttonStyle(.plain)
            Divider()
          }
        }

        SecuredByClerkView()
          .padding(.horizontal, 16)
      }
      .padding(.vertical, 16)
    }
  }

  private var createOrganizationRow: some View {
    HStack(spacing: 16) {
      Image(systemName: "plus")
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(theme.colors.foreground)
        .frame(width: 48)

      Text("Create organization", bundle: .module)
        .font(.body.weight(.semibold))
        .foregroundStyle(theme.colors.foreground)

      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 16)
  }

  // MARK: - Actions

  private func fetchOrganizationResources() async {
    guard let user else { return }

    let defaultsEnabled = clerk.environment?.organizationSettings.organizationCreationDefaults.enabled == true

    do {
      async let fetchedMemberships = user.getOrganizationMemberships(pageSize: pageSize)
      async let fetchedInvitations = user.getOrganizationInvitations(pageSize: pageSize, status: "pending")
      async let fetchedSuggestions = user.getOrganizationSuggestions(pageSize: pageSize, status: ["pending", "accepted"])
      async let fetchedDefaults = defaultsEnabled ? user.getOrganizationCreationDefaults() : nil

      let membershipsResult = try await fetchedMemberships
      let invitationsResult = try await fetchedInvitations
      let suggestionsResult = try await fetchedSuggestions

      membershipsPager.replace(with: membershipsResult)
      invitationsPager.replace(with: invitationsResult)
      suggestionsPager.replace(with: suggestionsResult)
      creationDefaults = try await fetchedDefaults
    } catch {
      self.error = error
    }

    isLoading = false
  }

  private func loadMoreMemberships() async {
    guard let user, !isLoadingMore, membershipsPager.hasNextPage else { return }

    membershipsPager.isLoadingMore = true
    defer { membershipsPager.isLoadingMore = false }

    do {
      let result = try await user.getOrganizationMemberships(offset: membershipsPager.offset, pageSize: pageSize)
      membershipsPager.append(result)
    } catch {
      self.error = error
    }
  }

  private func loadMoreInvitations() async {
    guard let user, !isLoadingMore, invitationsPager.hasNextPage else { return }

    invitationsPager.isLoadingMore = true
    defer { invitationsPager.isLoadingMore = false }

    do {
      let result = try await user.getOrganizationInvitations(offset: invitationsPager.offset, pageSize: pageSize, status: "pending")
      invitationsPager.append(result)
    } catch {
      self.error = error
    }
  }

  private func loadMoreSuggestions() async {
    guard let user, !isLoadingMore, suggestionsPager.hasNextPage else { return }

    suggestionsPager.isLoadingMore = true
    defer { suggestionsPager.isLoadingMore = false }

    do {
      let result = try await user.getOrganizationSuggestions(offset: suggestionsPager.offset, pageSize: pageSize, status: ["pending", "accepted"])
      suggestionsPager.append(result)
    } catch {
      self.error = error
    }
  }

  private func selectOrganization(id: String) async {
    guard let session = clerk.session else { return }

    do {
      try await clerk.auth.setActive(sessionId: session.id, organizationId: id)
      navigation.handleSessionTaskCompletion(session: clerk.session)
    } catch {
      self.error = organizationError(from: error)
    }
  }

  private func acceptInvitation(_ invitation: UserOrganizationInvitation) async {
    do {
      try await invitation.accept()
      acceptedInvitationOrgIds.insert(invitation.publicOrganizationData.id)
    } catch {
      self.error = error
    }
  }

  private func acceptSuggestion(_ suggestion: OrganizationSuggestion) async {
    do {
      let accepted = try await suggestion.accept()
      if let index = suggestionsPager.items.firstIndex(where: { $0.id == suggestion.id }) {
        suggestionsPager.items[index] = accepted
      }
    } catch {
      self.error = error
    }
  }

  private func displayRoleName(for role: String) -> String {
    switch role {
    case "org:admin": String(localized: "Admin", bundle: .module)
    case "org:member": String(localized: "Member", bundle: .module)
    default: role.replacingOccurrences(of: "org:", with: "").capitalized
    }
  }

  private func organizationError(from error: Error) -> Error {
    if let clerkError = error as? ClerkAPIError,
       ["organization_not_found_or_unauthorized", "not_a_member_in_organization"].contains(clerkError.code)
    {
      if user?.createOrganizationEnabled == true {
        return ClerkClientError(message: "You are no longer a member of this organization. Please choose or create another one.")
      } else {
        return ClerkClientError(message: "You are no longer a member of this organization. Please choose another one.")
      }
    }
    return error
  }
}

extension SessionTaskChooseOrganizationView {
  fileprivate struct PagerState<Item> {
    var items: [Item] = []
    var totalCount = 0
    var offset = 0
    var isLoadingMore = false

    var hasNextPage: Bool {
      offset < totalCount
    }
  }
}

extension SessionTaskChooseOrganizationView.PagerState where Item: Codable & Sendable {
  mutating func replace(with page: ClerkPaginatedResponse<Item>) {
    items = page.data
    totalCount = page.totalCount
    offset = page.data.count
  }

  mutating func append(_ page: ClerkPaginatedResponse<Item>) {
    items.append(contentsOf: page.data)
    totalCount = page.totalCount
    offset += page.data.count
  }
}

// MARK: - Organization Row

private struct OrganizationRow<Action: View>: View {
  let name: String
  let imageUrl: String
  var subtitle: String?
  let action: Action

  @Environment(\.clerkTheme) private var theme

  init(
    name: String,
    imageUrl: String,
    subtitle: String
  ) where Action == EmptyView {
    self.name = name
    self.imageUrl = imageUrl
    self.subtitle = subtitle
    action = EmptyView()
  }

  init(
    name: String,
    imageUrl: String,
    @ViewBuilder action: () -> Action
  ) {
    self.name = name
    self.imageUrl = imageUrl
    subtitle = nil
    self.action = action()
  }

  private var initials: String {
    String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
  }

  var body: some View {
    HStack(spacing: 16) {
      LazyImage(url: URL(string: imageUrl)) { state in
        if let image = state.image {
          image
            .resizable()
            .scaledToFill()
        } else {
          initialsView
        }
      }
      .frame(width: 48, height: 48)
      .clipShape(RoundedRectangle(cornerRadius: theme.design.borderRadius))

      VStack(alignment: .leading, spacing: 4) {
        Text(verbatim: name)
          .font(.body)
          .foregroundStyle(theme.colors.foreground)
          .lineLimit(1)

        if let subtitle {
          Text(verbatim: subtitle)
            .font(.subheadline)
            .foregroundStyle(theme.colors.mutedForeground)
        }
      }

      Spacer()

      action
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 16)
    .contentShape(Rectangle())
  }

  private var initialsView: some View {
    ZStack {
      RoundedRectangle(cornerRadius: theme.design.borderRadius)
        .fill(theme.colors.primary.gradient)
      Text(verbatim: initials)
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(theme.colors.primaryForeground)
    }
  }
}

#Preview("Choose Organization") {
  SessionTaskChooseOrganizationView()
    .clerkPreview()
}

#endif
