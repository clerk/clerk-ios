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

  @State private var sheetNavigation = OrganizationSwitcherSheetNavigation()
  @State private var summaryHeight: CGFloat = 220

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
  public init(
    hidePersonal: Bool = false
  ) {
    self.hidePersonal = hidePersonal
  }

  public var body: some View {
    if let user {
      Button {
        if activeOrganization == nil {
          sheetNavigation.presentedSheet = .accountList
        } else {
          sheetNavigation.summaryIsPresented = true
        }
      } label: {
        OrganizationSwitcherLabel(
          organization: activeOrganization,
          user: activeOrganization == nil && shouldShowPersonalAccount ? user : nil
        )
      }
      .buttonStyle(.plain)
      .tint(theme.colors.primary)
      .sheet(isPresented: $sheetNavigation.summaryIsPresented) {
        if let organization = activeOrganization {
          OrganizationSwitcherSummaryView(
            organization: organization,
            roleName: activeMembership?.roleName,
            contentHeight: $summaryHeight
          )
          .presentationDetents([.height(summaryHeight)])
          .environment(sheetNavigation)
        }
      }
      .sheet(item: $sheetNavigation.presentedSheet) { sheet in
        switch sheet {
        case .accountList:
          OrganizationListView(
            hidePersonal: hidePersonal,
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
