//
//  OrganizationSwitcher.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

/// A prebuilt control for viewing and changing the active organization.
///
/// `OrganizationSwitcher` displays the active organization, or the signed-in user's
/// personal account when no organization is selected. Tapping the control opens native
/// organization account controls for managing the active organization, switching to another
/// organization, accepting invitations, requesting to join suggested organizations, or creating
/// a new organization when allowed by the current environment.
///
/// The switcher renders only when Organizations are enabled and a user is signed in.
/// Personal account selection is hidden automatically when organization selection is
/// required by the environment.
///
/// ## Usage
///
/// Basic usage alongside ``UserButton``:
///
/// ```swift
/// struct HomeView: View {
///   var body: some View {
///     HStack(spacing: 16) {
///       UserButton()
///       OrganizationSwitcher()
///     }
///   }
/// }
/// ```
///
/// Compact usage in a navigation toolbar:
///
/// ```swift
/// .toolbar {
///   ToolbarItem(placement: .navigationBarTrailing) {
///     OrganizationSwitcher(displayMode: .compact)
///   }
/// }
/// ```
public struct OrganizationSwitcher<Route: Hashable, Destination: View>: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  private let hidePersonal: Bool
  private let displayMode: OrganizationSwitcherDisplayMode
  private let skipInvitationScreen: Bool
  private let customRows: [OrganizationProfileCustomRow<Route>]
  private let customDestination: (@MainActor (Route) -> Destination)?

  @State private var presentedSheet: PresentedSheet?

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

  private var activeOrganization: Organization? {
    clerk.organization
  }

  private var activeMembership: OrganizationMembership? {
    clerk.organizationMembership
  }

  /// Creates a new organization switcher.
  ///
  /// - Parameters:
  ///   - hidePersonal: Whether the personal account option should be hidden even when
  ///     personal account selection is allowed.
  ///   - displayMode: The visual presentation for the switcher trigger.
  ///   - skipInvitationScreen: Whether creating an organization should skip the
  ///     post-create invite step.
  public init(
    hidePersonal: Bool = false,
    displayMode: OrganizationSwitcherDisplayMode = .normal,
    skipInvitationScreen: Bool = false
  ) where Route == Never, Destination == EmptyView {
    self.init(
      hidePersonal: hidePersonal,
      displayMode: displayMode,
      skipInvitationScreen: skipInvitationScreen,
      customRows: [],
      customDestination: nil
    )
  }

  init(
    hidePersonal: Bool,
    displayMode: OrganizationSwitcherDisplayMode,
    skipInvitationScreen: Bool,
    customRows: [OrganizationProfileCustomRow<Route>],
    customDestination: (@MainActor (Route) -> Destination)?
  ) {
    self.hidePersonal = hidePersonal
    self.displayMode = displayMode
    self.skipInvitationScreen = skipInvitationScreen
    self.customRows = customRows
    self.customDestination = customDestination
  }

  public var body: some View {
    Group {
      if organizationsEnabled, let user {
        Button {
          if let activeOrganization {
            presentedSheet = .overview(activeOrganization)
          } else {
            presentedSheet = .accountList
          }
        } label: {
          OrganizationSwitcherLabel(
            organization: activeOrganization,
            user: activeOrganization == nil && shouldShowPersonalAccount ? user : nil,
            displayMode: displayMode
          )
        }
        .buttonStyle(.plain)
        .tint(theme.colors.primary)
      }
    }
    .sheet(item: $presentedSheet) { sheet in
      view(for: sheet)
    }
    .onChange(of: user?.id) { _, userId in
      if userId == nil {
        presentedSheet = nil
      }
    }
    .onChange(of: activeOrganization?.id) { _, organizationId in
      guard organizationId == nil else { return }

      switch presentedSheet {
      case .overview, .profile:
        presentedSheet = nil
      case .accountList, nil:
        break
      }
    }
  }

  @ViewBuilder
  private func view(for sheet: PresentedSheet) -> some View {
    switch sheet {
    case let .overview(organization):
      OrganizationSwitcherSheet(
        organization: organization,
        roleName: activeMembership?.roleName,
        onManage: {
          presentedSheet = .profile
        },
        onSwitchAccount: {
          presentedSheet = .accountList
        }
      )
    case .accountList:
      OrganizationListView(
        hidePersonal: hidePersonal,
        skipInvitationScreen: skipInvitationScreen,
        title: "Switch account",
        subtitle: nil
      )
    case .profile:
      OrganizationProfileView(
        isDismissable: true,
        navigationPath: nil,
        customRows: customRows,
        customDestination: customDestination
      )
    }
  }
}

extension OrganizationSwitcher {
  /// Replaces the custom rows shown in the presented organization profile.
  public func organizationProfileRows(
    _ rows: [OrganizationProfileCustomRow<Route>]
  ) -> OrganizationSwitcher<Route, Destination> {
    OrganizationSwitcher<Route, Destination>(
      hidePersonal: hidePersonal,
      displayMode: displayMode,
      skipInvitationScreen: skipInvitationScreen,
      customRows: rows,
      customDestination: customDestination
    )
  }
}

extension OrganizationSwitcher where Destination == EmptyView {
  /// Sets the custom destination builder used by custom rows in the presented organization profile.
  public func organizationProfileDestination<NewDestination: View>(
    @ViewBuilder _ destination: @escaping @MainActor (Route) -> NewDestination
  ) -> OrganizationSwitcher<Route, NewDestination> {
    OrganizationSwitcher<Route, NewDestination>(
      hidePersonal: hidePersonal,
      displayMode: displayMode,
      skipInvitationScreen: skipInvitationScreen,
      customRows: customRows,
      customDestination: destination
    )
  }
}

extension OrganizationSwitcher where Route == Never, Destination == EmptyView {
  /// Sets the custom rows shown in the presented organization profile.
  public func organizationProfileRows<NewRoute: Hashable>(
    _ rows: [OrganizationProfileCustomRow<NewRoute>]
  ) -> OrganizationSwitcher<NewRoute, EmptyView> {
    OrganizationSwitcher<NewRoute, EmptyView>(
      hidePersonal: hidePersonal,
      displayMode: displayMode,
      skipInvitationScreen: skipInvitationScreen,
      customRows: rows,
      customDestination: nil
    )
  }

  /// Sets the custom destination builder used by custom rows in the presented organization profile.
  public func organizationProfileDestination<NewRoute: Hashable, NewDestination: View>(
    for _: NewRoute.Type = NewRoute.self,
    @ViewBuilder _ destination: @escaping @MainActor (NewRoute) -> NewDestination
  ) -> OrganizationSwitcher<NewRoute, NewDestination> {
    OrganizationSwitcher<NewRoute, NewDestination>(
      hidePersonal: hidePersonal,
      displayMode: displayMode,
      skipInvitationScreen: skipInvitationScreen,
      customRows: [],
      customDestination: destination
    )
  }
}

extension OrganizationSwitcher {
  enum PresentedSheet: Hashable, Identifiable {
    case overview(Organization)
    case accountList
    case profile

    var id: Self {
      self
    }
  }
}

/// Controls whether the organization switcher trigger shows the full label or only the icon.
public struct OrganizationSwitcherDisplayMode: Sendable {
  enum Kind {
    case normal
    case compact
  }

  private static let defaultSize: CGFloat = 36

  let kind: Kind
  let size: CGFloat

  /// Shows icon, organization name, and disclosure chevron.
  public static let normal = Self(kind: .normal, size: defaultSize)

  /// Shows only the organization or account icon.
  public static let compact = Self(kind: .compact, size: defaultSize)

  /// Shows icon, organization name, and disclosure chevron.
  ///
  /// - Parameter size: The base visual size used to derive the trigger's icon,
  ///   spacing, text, chevron, and minimum tap target.
  public static func normal(size: CGFloat) -> Self {
    Self(kind: .normal, size: size)
  }

  /// Shows only the organization or account icon.
  ///
  /// - Parameter size: The base visual size used to derive the trigger's icon
  ///   and minimum tap target.
  public static func compact(size: CGFloat) -> Self {
    Self(kind: .compact, size: size)
  }
}

#Preview("Organization Switcher") {
  OrganizationSwitcher()
    .clerkPreview()
}

#endif
