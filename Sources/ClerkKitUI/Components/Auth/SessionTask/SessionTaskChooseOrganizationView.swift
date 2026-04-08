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

  @State private var memberships: [OrganizationMembership] = []
  @State private var membershipsTotalCount = 0
  @State private var membershipsOffset = 0
  @State private var invitations: [UserOrganizationInvitation] = []
  @State private var invitationsTotalCount = 0
  @State private var invitationsOffset = 0
  @State private var suggestions: [OrganizationSuggestion] = []
  @State private var suggestionsTotalCount = 0
  @State private var suggestionsOffset = 0
  @State private var acceptedInvitationOrgIds: Set<String> = []
  @State private var isLoading = true
  @State private var isLoadingMore = false
  @State private var creationDefaults: OrganizationCreationDefaults?
  @State private var error: Error?

  private var user: User? {
    clerk.user
  }

  private var hasExistingResources: Bool {
    !memberships.isEmpty || !invitations.isEmpty || !suggestions.isEmpty
  }

  private var membershipsHasNextPage: Bool {
    membershipsOffset < membershipsTotalCount
  }

  private var invitationsHasNextPage: Bool {
    invitationsOffset < invitationsTotalCount
  }

  private var suggestionsHasNextPage: Bool {
    suggestionsOffset < suggestionsTotalCount
  }

  private var hasNextPage: Bool {
    membershipsHasNextPage || invitationsHasNextPage || suggestionsHasNextPage
  }

  var body: some View {
    Group {
      if !isLoading, !hasExistingResources, user?.createOrganizationEnabled == false {
        GetHelpView(context: .sessionTask)
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

        VStack(spacing: 0) {
          Divider()

          ForEach(memberships) { membership in
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
              if membership.id == memberships.last?.id {
                Task { await loadMore(.memberships) }
              }
            }
            Divider()
          }

          if !membershipsHasNextPage {
            ForEach(invitations) { invitation in
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
                if invitation.id == invitations.last?.id {
                  Task { await loadMore(.invitations) }
                }
              }
              Divider()
            }
          }

          if !membershipsHasNextPage, !invitationsHasNextPage {
            ForEach(suggestions) { suggestion in
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
                if suggestion.id == suggestions.last?.id {
                  Task { await loadMore(.suggestions) }
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
      async let fetchedInvitations = user.getOrganizationInvitations(pageSize: pageSize)
      async let fetchedSuggestions = user.getOrganizationSuggestions(pageSize: pageSize, status: "pending")
      async let fetchedDefaults = defaultsEnabled ? user.getOrganizationCreationDefaults() : nil

      let membershipsResult = try await fetchedMemberships
      let invitationsResult = try await fetchedInvitations
      let suggestionsResult = try await fetchedSuggestions

      memberships = membershipsResult.data
      membershipsTotalCount = membershipsResult.totalCount
      membershipsOffset = membershipsResult.data.count
      invitations = invitationsResult.data.filter { $0.status == "pending" }
      invitationsTotalCount = invitationsResult.totalCount
      invitationsOffset = invitationsResult.data.count
      suggestions = suggestionsResult.data
      suggestionsTotalCount = suggestionsResult.totalCount
      suggestionsOffset = suggestionsResult.data.count
      creationDefaults = try await fetchedDefaults
    } catch {
      self.error = error
    }

    isLoading = false
  }

  private enum OrganizationSection {
    case memberships, invitations, suggestions
  }

  private func loadMore(_ section: OrganizationSection) async {
    guard let user, !isLoadingMore else { return }

    switch section {
    case .memberships: guard membershipsHasNextPage else { return }
    case .invitations: guard invitationsHasNextPage else { return }
    case .suggestions: guard suggestionsHasNextPage else { return }
    }

    isLoadingMore = true
    defer { isLoadingMore = false }

    do {
      switch section {
      case .memberships:
        let result = try await user.getOrganizationMemberships(offset: membershipsOffset, pageSize: pageSize)
        memberships.append(contentsOf: result.data)
        membershipsTotalCount = result.totalCount
        membershipsOffset += result.data.count
      case .invitations:
        let result = try await user.getOrganizationInvitations(offset: invitationsOffset, pageSize: pageSize)
        invitations.append(contentsOf: result.data.filter { $0.status == "pending" })
        invitationsTotalCount = result.totalCount
        invitationsOffset += result.data.count
      case .suggestions:
        let result = try await user.getOrganizationSuggestions(offset: suggestionsOffset, pageSize: pageSize, status: "pending")
        suggestions.append(contentsOf: result.data)
        suggestionsTotalCount = result.totalCount
        suggestionsOffset += result.data.count
      }
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
      if let index = suggestions.firstIndex(where: { $0.id == suggestion.id }) {
        suggestions[index] = accepted
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

// MARK: - Action Label

private struct ActionLabel: View {
  let text: LocalizedStringKey
  var isLoading: Bool = false

  @Environment(\.clerkTheme) private var theme

  init(_ text: LocalizedStringKey, isLoading: Bool = false) {
    self.text = text
    self.isLoading = isLoading
  }

  var body: some View {
    Text(text, bundle: .module)
      .font(.subheadline)
      .foregroundStyle(theme.colors.foreground)
      .overlayProgressView(isActive: isLoading) {
        SpinnerView()
          .frame(width: 14, height: 14)
      }
      .padding(.horizontal, 14)
      .frame(height: 32)
      .background(theme.colors.background)
      .clipShape(.rect(cornerRadius: theme.design.borderRadius))
      .overlay {
        RoundedRectangle(cornerRadius: theme.design.borderRadius)
          .strokeBorder(theme.colors.buttonBorder, lineWidth: 1)
      }
      .shadow(color: theme.colors.buttonBorder, radius: 1, x: 0, y: 1)
  }
}

#Preview("Choose Organization") {
  SessionTaskChooseOrganizationView()
    .clerkPreview()
}

#endif
