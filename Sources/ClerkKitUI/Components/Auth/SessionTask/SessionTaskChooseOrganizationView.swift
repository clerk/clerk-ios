//
//  SessionTaskChooseOrganizationView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

/// A view shown when a session requires the user to choose or create an organization
/// before the session can become active.
struct SessionTaskChooseOrganizationView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation

  @State private var accountList = OrganizationAccountListModel()

  private var user: User? {
    clerk.user
  }

  var body: some View {
    Group {
      if !accountList.isLoading, !accountList.hasExistingResources, user?.createOrganizationEnabled == false {
        GetHelpView(context: .sessionTask(.organizationRequired))
          .navigationBarBackButtonHidden()
          .navigationBarTitleDisplayMode(.inline)
          .preGlassSolidNavBar()
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              UserButton(presentationContext: .sessionTaskToolbar)
            }
          }
      } else if !accountList.isLoading, !accountList.hasExistingResources {
        SessionTaskCreateOrganizationView(creationDefaults: accountList.creationDefaults)
      } else {
        Group {
          if accountList.isLoading {
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
    .clerkErrorPresenting($accountList.error, onDismiss: { _ in
      guard accountList.isLoading, user != nil else { return }
      Task { await fetchOrganizationResources() }
    })
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

          OrganizationPaginatedListSection(
            items: accountList.membershipsPager.items,
            hasNextPage: accountList.membershipsPager.hasNextPage,
            onLoadMore: loadMoreMemberships
          ) { membership in
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
          }

          if !accountList.membershipsPager.hasNextPage {
            OrganizationPaginatedListSection(
              items: accountList.invitationsPager.items,
              hasNextPage: accountList.invitationsPager.hasNextPage,
              onLoadMore: loadMoreInvitations
            ) { invitation in
              Group {
                if accountList.isInvitationAccepted(invitation) {
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
                  OrganizationRow(
                    name: invitation.publicOrganizationData.name,
                    imageUrl: invitation.publicOrganizationData.imageUrl
                  ) {
                    AsyncButton {
                      await acceptInvitation(invitation)
                    } label: { isRunning in
                      PillButtonLabelView("Join", isLoading: isRunning)
                    }
                    .buttonStyle(.plain)
                  }
                }
              }
            }
          }

          if !accountList.membershipsPager.hasNextPage, !accountList.invitationsPager.hasNextPage {
            OrganizationPaginatedListSection(
              items: accountList.suggestionsPager.items,
              hasNextPage: accountList.suggestionsPager.hasNextPage,
              onLoadMore: loadMoreSuggestions
            ) { suggestion in
              Group {
                if suggestion.status == "accepted" {
                  OrganizationRow(
                    name: suggestion.publicOrganizationData.name,
                    imageUrl: suggestion.publicOrganizationData.imageUrl,
                    subtitle: "Pending approval"
                  )
                } else {
                  OrganizationRow(
                    name: suggestion.publicOrganizationData.name,
                    imageUrl: suggestion.publicOrganizationData.imageUrl
                  ) {
                    AsyncButton {
                      await acceptSuggestion(suggestion)
                    } label: { isRunning in
                      PillButtonLabelView("Request to join", isLoading: isRunning)
                    }
                    .buttonStyle(.plain)
                  }
                }
              }
            }
          }

          if accountList.isLoadingMore {
            SpinnerView()
              .frame(width: 24, height: 24)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 16)
          }

          if !accountList.hasNextPage, user?.createOrganizationEnabled == true {
            Button {
              navigation.path.append(.sessionTaskCreateOrganization(creationDefaults: accountList.creationDefaults))
            } label: {
              OrganizationCreateRow()
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

  // MARK: - Actions

  private func fetchOrganizationResources() async {
    let defaultsEnabled = clerk.environment?.organizationSettings.organizationCreationDefaults.enabled == true
    await accountList.loadInitial(user: user, includeCreationDefaults: defaultsEnabled)
  }

  private func loadMoreMemberships() async {
    await accountList.loadMoreMemberships(user: user)
  }

  private func loadMoreInvitations() async {
    await accountList.loadMoreInvitations(user: user)
  }

  private func loadMoreSuggestions() async {
    await accountList.loadMoreSuggestions(user: user)
  }

  private func selectOrganization(id: String) async {
    guard let session = clerk.session else { return }

    do {
      try await clerk.auth.setActive(sessionId: session.id, organizationId: id)
      navigation.handleSessionTaskCompletion(session: clerk.session)
    } catch {
      accountList.error = organizationError(from: error)
    }
  }

  private func acceptInvitation(_ invitation: UserOrganizationInvitation) async {
    await accountList.acceptInvitation(invitation)
  }

  private func acceptSuggestion(_ suggestion: OrganizationSuggestion) async {
    await accountList.acceptSuggestion(suggestion)
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

#Preview("Choose Organization") {
  SessionTaskChooseOrganizationView()
    .clerkPreview()
}

#endif
