//
//  OrganizationSwitcher.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

/// A prebuilt organization switcher that opens organization account controls.
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
  ///   - hidePersonal: Whether the personal account option should be hidden.
  ///   - displayMode: The visual presentation for the switcher trigger.
  ///   - skipInvitationScreen: Whether creating an organization should skip the post-create invite step.
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
