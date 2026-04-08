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

  @State private var memberships: [OrganizationMembership] = []
  @State private var invitations: [UserOrganizationInvitation] = []
  @State private var suggestions: [OrganizationSuggestion] = []
  @State private var isLoading = true
  @State private var creationDefaults: OrganizationCreationDefaults?
  @State private var error: Error?

  private var user: User? {
    clerk.user
  }

  private var hasExistingResources: Bool {
    !memberships.isEmpty || !invitations.isEmpty || !suggestions.isEmpty
  }

  var body: some View {
    Group {
      if !isLoading, !hasExistingResources {
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
    .task {
      await fetchOrganizationResources()
    }
  }

  // MARK: - Choose Organization

  private var chooseOrganizationContent: some View {
    ScrollView {
      VStack(spacing: 32) {
        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Choose an Organization")
          HeaderView(style: .subtitle, text: "Join an existing organization or create a new one")
        }
        .padding(.horizontal, 16)

        VStack(spacing: 0) {
          Divider()

          ForEach(memberships) { membership in
            AsyncButton {
              await selectOrganization(id: membership.organization.id)
            } label: { isRunning in
              OrganizationRow(
                name: membership.organization.name,
                imageUrl: membership.organization.imageUrl,
                subtitle: membership.roleName,
                isLoading: isRunning
              )
            }
            .buttonStyle(.plain)
            Divider()
          }

          ForEach(invitations) { invitation in
            AsyncButton {
              await acceptInvitation(invitation)
            } label: { isRunning in
              OrganizationRow(
                name: invitation.publicOrganizationData.name,
                imageUrl: invitation.publicOrganizationData.imageUrl,
                subtitle: String(localized: "Join", bundle: .module),
                isLoading: isRunning
              )
            }
            .buttonStyle(.plain)
            Divider()
          }

          ForEach(suggestions) { suggestion in
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
                  imageUrl: suggestion.publicOrganizationData.imageUrl,
                  subtitle: String(localized: "Request to join", bundle: .module),
                  isLoading: isRunning
                )
              }
              .buttonStyle(.plain)
            }
            Divider()
          }

          if user?.createOrganizationEnabled == true {
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

    do {
      async let fetchedMemberships = user.getOrganizationMemberships()
      async let fetchedInvitations = user.getOrganizationInvitations()
      async let fetchedSuggestions = user.getOrganizationSuggestions(status: "pending")

      memberships = try await fetchedMemberships.data
      invitations = try await fetchedInvitations.data.filter { $0.status == "pending" }
      suggestions = try await fetchedSuggestions.data
    } catch {
      self.error = error
    }

    if clerk.environment?.organizationSettings.organizationCreationDefaults.enabled == true {
      creationDefaults = try? await user.getOrganizationCreationDefaults()
    }

    isLoading = false
  }

  private func selectOrganization(id: String) async {
    guard let session = clerk.session else { return }

    do {
      try await clerk.auth.setActive(sessionId: session.id, organizationId: id)
      navigation.handleSessionTaskCompletion(session: clerk.session)
    } catch {
      self.error = error
    }
  }

  private func acceptInvitation(_ invitation: UserOrganizationInvitation) async {
    do {
      let accepted = try await invitation.accept()
      await selectOrganization(id: accepted.publicOrganizationData.id)
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
}

// MARK: - Organization Row

private struct OrganizationRow: View {
  let name: String
  let imageUrl: String
  let subtitle: String
  var isLoading: Bool = false

  @Environment(\.clerkTheme) private var theme

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

        if isLoading {
          SpinnerView()
            .frame(width: 16, height: 16)
        } else {
          Text(verbatim: subtitle)
            .font(.subheadline)
            .foregroundStyle(theme.colors.mutedForeground)
        }
      }

      Spacer()
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

#Preview("Choose Organization") {
  SessionTaskChooseOrganizationView()
    .clerkPreview()
}

#endif
