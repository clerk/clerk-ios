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
/// The switcher renders only when a user is signed in. Personal account selection is hidden
/// automatically when organization selection is required by the environment.
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
public struct OrganizationSwitcher: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  private let hidePersonal: Bool
  private let displayMode: DisplayMode
  private let skipInvitationScreen: Bool

  @State private var sheetNavigation = OrganizationSwitcherSheetNavigation()
  @State private var overviewHeight: CGFloat = 220

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
    displayMode: DisplayMode = .normal,
    skipInvitationScreen: Bool = false
  ) {
    self.hidePersonal = hidePersonal
    self.displayMode = displayMode
    self.skipInvitationScreen = skipInvitationScreen
  }

  public var body: some View {
    if let user {
      Button {
        if activeOrganization == nil {
          sheetNavigation.presentedSheet = .accountList
        } else {
          sheetNavigation.overviewIsPresented = true
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
      .sheet(isPresented: $sheetNavigation.overviewIsPresented) {
        if let organization = activeOrganization {
          OrganizationSwitcherOverviewView(
            organization: organization,
            roleName: activeMembership?.roleName,
            contentHeight: $overviewHeight
          )
          .presentationDetents([.height(overviewHeight)])
          .environment(sheetNavigation)
        }
      }
      .sheet(item: $sheetNavigation.presentedSheet) { sheet in
        switch sheet {
        case .accountList:
          OrganizationListView(
            hidePersonal: hidePersonal,
            skipInvitationScreen: skipInvitationScreen,
            title: "Switch account",
            subtitle: nil
          )
        case .profile:
          OrganizationProfileView()
        }
      }
    }
  }
}

extension OrganizationSwitcher {
  /// Controls whether the organization switcher trigger shows the full label or only the icon.
  public struct DisplayMode: Sendable {
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

  enum PresentedSheet: String, Identifiable {
    case accountList
    case profile

    var id: String {
      rawValue
    }
  }
}

#Preview("Organization Switcher") {
  OrganizationSwitcher()
    .clerkPreview()
}

#endif
