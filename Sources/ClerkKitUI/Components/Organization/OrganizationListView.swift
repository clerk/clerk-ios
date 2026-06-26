//
//  OrganizationListView.swift
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

/// A prebuilt view for choosing a personal account or organization.
///
/// `OrganizationListView` displays the signed-in user's personal account, organization
/// memberships, pending organization invitations, suggested organizations, and a create
/// organization entry when organization creation is available.
///
/// The view renders only when Organizations are enabled and a user is signed in.
/// Selecting a personal account clears the active organization. Selecting an organization
/// makes that organization active. Personal account selection is hidden automatically when
/// organization selection is required by the environment.
///
/// ## Usage
///
/// As a dismissible sheet:
///
/// ```swift
/// struct AccountPickerButton: View {
///   @State private var accountPickerIsPresented = false
///
///   var body: some View {
///     Button("Switch account") {
///       accountPickerIsPresented = true
///     }
///     .sheet(isPresented: $accountPickerIsPresented) {
///       OrganizationListView()
///     }
///   }
/// }
/// ```
///
/// Embedded in a parent `NavigationStack`:
///
/// ```swift
/// struct AccountPickerView: View {
///   @State private var path = NavigationPath()
///
///   var body: some View {
///     NavigationStack(path: $path) {
///       OrganizationListView(isDismissible: false, navigationPath: $path)
///     }
///   }
/// }
/// ```
public struct OrganizationListView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss

  private let hidePersonal: Bool
  private let isDismissible: Bool
  private let skipInvitationScreen: Bool
  private let navigationPath: Binding<NavigationPath>?
  private let title: LocalizedStringKey
  private let subtitle: LocalizedStringKey?

  @State private var accountList = OrganizationAccountListDataSource()
  @State private var internalPath = NavigationPath()
  @State private var isSelectingAccount = false

  private var user: User? {
    clerk.user
  }

  private var forceOrganizationSelection: Bool {
    clerk.environment?.organizationSettings.forceOrganizationSelection == true
  }

  private var organizationsEnabled: Bool {
    clerk.environment?.organizationSettings.enabled == true
  }

  private var shouldShowPersonalAccount: Bool {
    user != nil && !hidePersonal && !forceOrganizationSelection
  }

  private var shouldStartCreateOrganizationFlow: Bool {
    !accountList.isLoading
      && !accountList.hasExistingResources
      && !shouldShowPersonalAccount
      && user?.createOrganizationEnabled == true
  }

  private var shouldShowContentHeader: Bool {
    subtitle != nil
  }

  /// Creates a new organization list view.
  ///
  /// - Parameters:
  ///   - hidePersonal: Whether the personal account row should be hidden even when
  ///     personal account selection is allowed.
  ///   - isDismissible: Whether the view can dismiss itself after account selection and
  ///     show a dismiss button.
  ///   - navigationPath: An optional parent navigation path for embedded usage. Pass
  ///     a parent path when the view is hosted inside your own `NavigationStack`.
  ///   - skipInvitationScreen: Whether creating an organization should skip the
  ///     post-create invite step.
  public init(
    hidePersonal: Bool = false,
    isDismissible: Bool = true,
    navigationPath: Binding<NavigationPath>? = nil,
    skipInvitationScreen: Bool = false
  ) {
    self.init(
      hidePersonal: hidePersonal,
      isDismissible: isDismissible,
      navigationPath: navigationPath,
      skipInvitationScreen: skipInvitationScreen,
      title: "Choose an account",
      subtitle: "Select the account with which you wish to continue."
    )
  }

  init(
    hidePersonal: Bool = false,
    isDismissible: Bool = true,
    navigationPath: Binding<NavigationPath>? = nil,
    skipInvitationScreen: Bool = false,
    title: LocalizedStringKey,
    subtitle: LocalizedStringKey?
  ) {
    self.hidePersonal = hidePersonal
    self.isDismissible = isDismissible
    self.skipInvitationScreen = skipInvitationScreen
    self.navigationPath = navigationPath
    self.title = title
    self.subtitle = subtitle
  }

  public var body: some View {
    if organizationsEnabled, user != nil {
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
        guard !accountList.hasExistingResources, user != nil else { return }
        Task { await fetchOrganizationResources() }
      })
      .taskOnce {
        await fetchOrganizationResources()
      }
      #if os(macOS)
      .frame(width: 560, height: 620, alignment: .topLeading)
      #endif
    }
  }

  // MARK: - Content

  private var content: some View {
    Group {
      if accountList.isLoading {
        SpinnerView()
          .frame(width: 32, height: 32)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if shouldStartCreateOrganizationFlow {
        createOrganizationContent
      } else {
        listContent
      }
    }
    .background(theme.colors.background)
    .securedByClerkFooter(macOSDismissAction: isDismissible ? { dismiss() } : nil)
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    .preGlassSolidNavBar()
    .navigationDestination(for: Destination.self) { destination in
      switch destination {
      case .createOrganization:
        createOrganizationContent
      }
    }
    .toolbar {
      #if os(iOS)
      if isDismissible {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
          .foregroundStyle(theme.colors.primary)
        }
      }
      #endif

      if !accountList.isLoading, !shouldStartCreateOrganizationFlow, !shouldShowContentHeader {
        ToolbarItem(placement: .principal) {
          Text(title, bundle: .module)
            .font(theme.fonts.headline)
            .foregroundStyle(theme.colors.foreground)
        }
      }
    }
  }

  private var listContent: some View {
    ScrollView {
      VStack(spacing: 32) {
        if shouldShowContentHeader {
          accountListHeader
        }

        OrganizationAccountListSections(
          accountList: accountList,
          mode: .accountSwitcher(showsPersonalAccount: shouldShowPersonalAccount),
          onSelection: { selection in
            switch selection {
            case .personalAccount:
              Task { await selectPersonalAccount() }
            case .organization(let id):
              Task { await selectOrganization(id: id) }
            }
          },
          onCreateOrganization: navigateToCreateOrganization
        )
        .disabled(isSelectingAccount)
      }
      .padding(.top, 16)
    }
  }

  private var accountListHeader: some View {
    VStack(spacing: 8) {
      HeaderView(style: .title, text: title)

      if let subtitle {
        HeaderView(style: .subtitle, text: subtitle)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(.horizontal, 16)
  }

  private var createOrganizationContent: some View {
    OrganizationCreateFlowView(skipInvitationScreen: skipInvitationScreen) {
      completeCreateOrganizationFlow()
    }
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    .preGlassSolidNavBar()
  }
}

// MARK: - Actions

extension OrganizationListView {
  private func fetchOrganizationResources() async {
    await accountList.loadInitial(user: user, includeCreationDefaults: false)
  }

  private func selectPersonalAccount() async {
    guard !isSelectingAccount, let session = clerk.session else { return }

    isSelectingAccount = true
    defer { isSelectingAccount = false }

    do {
      try await clerk.auth.setActive(sessionId: session.id, organizationId: nil)
      dismissIfNeeded()
    } catch {
      accountList.error = error
    }
  }

  private func selectOrganization(id: String) async {
    guard !isSelectingAccount, let session = clerk.session else { return }

    isSelectingAccount = true
    defer { isSelectingAccount = false }

    do {
      try await clerk.auth.setActive(sessionId: session.id, organizationId: id)
      dismissIfNeeded()
    } catch {
      accountList.error = organizationError(from: error)
    }
  }

  private func navigateToCreateOrganization() {
    if let navigationPath {
      navigationPath.wrappedValue.append(Destination.createOrganization)
    } else {
      internalPath.append(Destination.createOrganization)
    }
  }

  private func dismissIfNeeded() {
    guard isDismissible else { return }
    dismiss()
  }

  private func completeCreateOrganizationFlow() {
    if isDismissible {
      dismiss()
    } else {
      popCreateOrganizationFlow()
      Task { await fetchOrganizationResources() }
    }
  }

  private func popCreateOrganizationFlow() {
    if let navigationPath {
      guard !navigationPath.wrappedValue.isEmpty else { return }
      navigationPath.wrappedValue.removeLast()
    } else {
      guard !internalPath.isEmpty else { return }
      internalPath.removeLast()
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
