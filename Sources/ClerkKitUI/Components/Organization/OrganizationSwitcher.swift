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
  private let onManageOrganization: ((Organization) -> Void)?

  @State private var presentedSheet: PresentedSheet?
  @State private var summaryHeight: CGFloat = 220
  @State private var activeMembership: OrganizationMembership?
  @State private var activeOrganization: Organization?
  @State private var error: Error?

  private var user: User? {
    clerk.user
  }

  private var activeOrganizationId: String? {
    clerk.session?.lastActiveOrganizationId
  }

  private var forceOrganizationSelection: Bool {
    clerk.environment?.organizationSettings.forceOrganizationSelection == true
  }

  private var shouldShowPersonalAccount: Bool {
    user != nil && !hidePersonal && !forceOrganizationSelection
  }

  /// Creates a new organization switcher.
  ///
  /// - Parameters:
  ///   - hidePersonal: Whether the personal account option should be hidden.
  ///   - onManageOrganization: Optional action for the Manage row until the prebuilt organization profile view is available.
  public init(
    hidePersonal: Bool = false,
    onManageOrganization: ((Organization) -> Void)? = nil
  ) {
    self.hidePersonal = hidePersonal
    self.onManageOrganization = onManageOrganization
  }

  public var body: some View {
    if let user {
      Button {
        if resolvedActiveOrganization == nil {
          presentedSheet = .accountList
        } else {
          presentedSheet = .summary
        }
      } label: {
        OrganizationSwitcherLabel(
          organization: resolvedActiveOrganization,
          user: activeOrganizationId == nil && shouldShowPersonalAccount ? user : nil
        )
      }
      .buttonStyle(.plain)
      .tint(theme.colors.primary)
      .clerkErrorPresenting($error)
      .task(id: activeOrganizationId) {
        await loadActiveOrganization()
      }
      .sheet(item: $presentedSheet) { sheet in
        switch sheet {
        case .summary:
          if let organization = resolvedActiveOrganization {
            OrganizationSwitcherSummaryView(
              organization: organization,
              roleName: activeMembership?.roleName,
              contentHeight: $summaryHeight,
              onManageOrganization: onManageOrganization,
              onSwitchAccount: {
                presentedSheet = .accountList
              }
            )
            .presentationDetents([.height(summaryHeight)])
          }
        case .accountList:
          OrganizationListView(
            hidePersonal: hidePersonal,
            title: "Switch account",
            subtitle: nil
          )
        }
      }
    }
  }

  private var resolvedActiveOrganization: Organization? {
    activeMembership?.organization ?? activeOrganization
  }

  private func loadActiveOrganization() async {
    guard let activeOrganizationId else {
      activeMembership = nil
      activeOrganization = nil
      return
    }

    if let membership = user?.organizationMemberships?.first(where: { $0.organization.id == activeOrganizationId }) {
      activeMembership = membership
      activeOrganization = membership.organization
      return
    }

    do {
      activeMembership = nil
      activeOrganization = try await clerk.organizations.get(id: activeOrganizationId)
    } catch {
      self.error = error
    }
  }
}

extension OrganizationSwitcher {
  enum PresentedSheet: String, Identifiable {
    case summary
    case accountList

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
