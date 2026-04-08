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
        SessionTaskCreateOrganizationView()
      } else {
        Group {
          if isLoading {
            ProgressView()
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
      VStack(spacing: 0) {
        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Choose an organization")
          HeaderView(style: .subtitle, text: "to continue")
        }
        .padding(.bottom, 32)

        VStack(spacing: 12) {
          ForEach(memberships) { membership in
            AsyncButton {
              await selectOrganization(id: membership.organization.id)
            } label: { _ in
              OrganizationRow(
                name: membership.organization.name,
                imageUrl: membership.organization.imageUrl
              )
            }
            .buttonStyle(.plain)
          }

          ForEach(invitations) { invitation in
            AsyncButton {
              await acceptInvitation(invitation)
            } label: { _ in
              OrganizationRow(
                name: invitation.publicOrganizationData.name,
                imageUrl: invitation.publicOrganizationData.imageUrl,
                badge: "Invitation"
              )
            }
            .buttonStyle(.plain)
          }

          ForEach(suggestions) { suggestion in
            AsyncButton {
              await acceptSuggestion(suggestion)
            } label: { _ in
              OrganizationRow(
                name: suggestion.publicOrganizationData.name,
                imageUrl: suggestion.publicOrganizationData.imageUrl,
                badge: "Suggestion"
              )
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.bottom, 24)

        Button {
          navigation.path.append(.sessionTaskCreateOrganization)
        } label: {
          Text("Create a new organization", bundle: .module)
        }
        .buttonStyle(.secondary())
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(16)
    }
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
      await selectOrganization(id: accepted.publicOrganizationData.id)
    } catch {
      self.error = error
    }
  }
}

// MARK: - Organization Row

private struct OrganizationRow: View {
  let name: String
  let imageUrl: String
  var badge: LocalizedStringKey?

  @Environment(\.clerkTheme) private var theme

  var body: some View {
    HStack(spacing: 12) {
      LazyImage(url: URL(string: imageUrl)) { state in
        if let image = state.image {
          image
            .resizable()
            .scaledToFill()
        } else {
          Color(theme.colors.muted)
        }
      }
      .frame(width: 36, height: 36)
      .clipShape(RoundedRectangle(cornerRadius: 8))

      VStack(alignment: .leading, spacing: 2) {
        Text(verbatim: name)
          .font(.footnote.weight(.medium))
          .foregroundStyle(theme.colors.foreground)

        if let badge {
          Text(badge, bundle: .module)
            .font(.caption2)
            .foregroundStyle(theme.colors.mutedForeground)
        }
      }

      Spacer()

      Image(systemName: "chevron.right")
        .font(.caption.weight(.semibold))
        .foregroundStyle(theme.colors.mutedForeground)
    }
    .padding(12)
    .background(theme.colors.muted.opacity(0.3))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(theme.colors.border, lineWidth: 1)
    )
  }
}

#Preview("Choose Organization") {
  SessionTaskChooseOrganizationView()
    .clerkPreview()
}

#endif
