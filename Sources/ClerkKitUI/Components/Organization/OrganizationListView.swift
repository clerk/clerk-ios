//
//  OrganizationListView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

/// A prebuilt view for choosing a personal account or organization.
public struct OrganizationListView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss

  private let hidePersonal: Bool
  private let isDismissable: Bool
  private let navigationPath: Binding<NavigationPath>?
  private let title: LocalizedStringKey
  private let subtitle: LocalizedStringKey?

  @State private var accountList = OrganizationAccountListModel()
  @State private var internalPath = NavigationPath()
  @State private var didNavigateToCreateOrganization = false

  private var user: User? {
    clerk.user
  }

  private var forceOrganizationSelection: Bool {
    clerk.environment?.organizationSettings.forceOrganizationSelection == true
  }

  private var shouldShowPersonalAccount: Bool {
    user != nil && !hidePersonal && !forceOrganizationSelection
  }

  private var activeOrganization: Organization? {
    clerk.organization
  }

  private var personalAccountIsSelected: Bool {
    activeOrganization == nil
  }

  /// Creates a new organization list view.
  ///
  /// - Parameters:
  ///   - hidePersonal: Whether the personal account row should be hidden.
  ///   - isDismissable: Whether the view can dismiss itself after account selection and show a dismiss button.
  ///   - navigationPath: An optional parent navigation path for embedded usage.
  public init(
    hidePersonal: Bool = false,
    isDismissable: Bool = true,
    navigationPath: Binding<NavigationPath>? = nil
  ) {
    self.init(
      hidePersonal: hidePersonal,
      isDismissable: isDismissable,
      navigationPath: navigationPath,
      title: "Choose an account",
      subtitle: "Select the account with which you wish to continue."
    )
  }

  init(
    hidePersonal: Bool = false,
    isDismissable: Bool = true,
    navigationPath: Binding<NavigationPath>? = nil,
    title: LocalizedStringKey,
    subtitle: LocalizedStringKey?
  ) {
    self.hidePersonal = hidePersonal
    self.isDismissable = isDismissable
    self.navigationPath = navigationPath
    self.title = title
    self.subtitle = subtitle
  }

  public var body: some View {
    if user != nil {
      Group {
        if navigationPath == nil {
          NavigationStack(path: $internalPath) {
            content
          }
        } else {
          content
        }
      }
      .tint(theme.colors.primary)
      .presentationBackground(theme.colors.background)
      .background(theme.colors.background)
      .clerkErrorPresenting($accountList.error, onDismiss: { _ in
        guard accountList.isLoading, user != nil else { return }
        Task { await fetchOrganizationResources() }
      })
      .taskOnce {
        await fetchOrganizationResources()
      }
    }
  }

  // MARK: - Content

  private var content: some View {
    Group {
      if accountList.isLoading {
        SpinnerView()
          .frame(width: 32, height: 32)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        listContent
      }
    }
    .background(theme.colors.background)
    .navigationBarTitleDisplayMode(.inline)
    .preGlassSolidNavBar()
    .navigationDestination(for: Destination.self) { destination in
      switch destination {
      case .createOrganization:
        createOrganizationContent
      }
    }
    .toolbar {
      if isDismissable {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
          .foregroundStyle(theme.colors.primary)
        }
      }

      ToolbarItem(placement: .principal) {
        Text(title, bundle: .module)
          .font(theme.fonts.headline)
          .foregroundStyle(theme.colors.foreground)
      }
    }
  }

  private var listContent: some View {
    ScrollView {
      VStack(spacing: 32) {
        if let subtitle {
          Text(subtitle, bundle: .module)
            .font(theme.fonts.subheadline)
            .foregroundStyle(theme.colors.mutedForeground)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
        }

        LazyVStack(spacing: 0) {
          Divider()

          if let user, shouldShowPersonalAccount {
            AsyncButton {
              guard !personalAccountIsSelected else { return }
              await selectPersonalAccount()
            } label: { _ in
              OrganizationPersonalAccountRow(user: user) {
                if personalAccountIsSelected {
                  OrganizationSelectedAccessory()
                }
              }
            }
            .buttonStyle(.plain)
            Divider()
          }

          OrganizationPaginatedListSection(
            items: accountList.membershipsPager.items,
            hasNextPage: accountList.membershipsPager.hasNextPage,
            onLoadMore: loadMoreMemberships
          ) { membership in
            let isSelected = membership.organization.id == activeOrganization?.id
            AsyncButton {
              guard !isSelected else { return }
              await selectOrganization(id: membership.organization.id)
            } label: { _ in
              OrganizationRow(
                name: membership.organization.name,
                imageUrl: membership.organization.imageUrl,
                subtitle: membership.roleName
              ) {
                if isSelected {
                  OrganizationSelectedAccessory()
                }
              }
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
              navigateToCreateOrganization()
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
      .padding(.top, 16)
    }
  }

  private var createOrganizationContent: some View {
    OrganizationCreateView(creationDefaults: accountList.creationDefaults) {
      dismissIfNeeded()
    }
    .navigationBarTitleDisplayMode(.inline)
    .preGlassSolidNavBar()
  }

  // MARK: - Actions

  private func fetchOrganizationResources() async {
    let defaultsEnabled = clerk.environment?.organizationSettings.organizationCreationDefaults.enabled == true
    await accountList.loadInitial(user: user, includeCreationDefaults: defaultsEnabled)
    navigateToCreateOrganizationIfNeeded()
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

  private func selectPersonalAccount() async {
    guard let session = clerk.session else { return }

    do {
      try await clerk.auth.setActive(sessionId: session.id, organizationId: nil)
      dismissIfNeeded()
    } catch {
      accountList.error = error
    }
  }

  private func selectOrganization(id: String) async {
    guard let session = clerk.session else { return }

    do {
      try await clerk.auth.setActive(sessionId: session.id, organizationId: id)
      dismissIfNeeded()
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

  private func navigateToCreateOrganization() {
    if let navigationPath {
      navigationPath.wrappedValue.append(Destination.createOrganization)
    } else {
      internalPath.append(Destination.createOrganization)
    }
  }

  private func navigateToCreateOrganizationIfNeeded() {
    guard !didNavigateToCreateOrganization else { return }
    guard !accountList.isLoading, !accountList.hasExistingResources else { return }
    guard !shouldShowPersonalAccount, user?.createOrganizationEnabled == true else { return }
    didNavigateToCreateOrganization = true
    navigateToCreateOrganization()
  }

  private func dismissIfNeeded() {
    guard isDismissable else { return }
    dismiss()
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
      return ClerkClientError(message: "You are no longer a member of this organization. Please choose another one.")
    }
    return error
  }
}

extension OrganizationListView {
  enum Destination: Hashable {
    case createOrganization
  }
}

#Preview("Organization List") {
  OrganizationListView()
    .clerkPreview()
}

#endif
