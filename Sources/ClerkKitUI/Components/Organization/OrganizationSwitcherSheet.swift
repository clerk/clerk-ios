//
//  OrganizationSwitcherSheet.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

/// A sheet that shows the active organization with actions to manage it or switch accounts.
///
/// `OrganizationSwitcherSheet` renders only the active organization overview. When using this
/// view directly, present ``OrganizationProfileView`` and ``OrganizationListView`` from the
/// action callbacks.
///
/// ```swift
/// struct OrganizationActionsView: View {
///   @Environment(Clerk.self) private var clerk
///   @State private var presentedSheet: PresentedSheet?
///
///   var body: some View {
///     Button("Organization") {
///       if let organization = clerk.organization {
///         presentedSheet = .overview(organization)
///       }
///     }
///     .sheet(item: $presentedSheet) { sheet in
///       switch sheet {
///       case let .overview(organization):
///         OrganizationSwitcherSheet(
///           organization: organization,
///           roleName: clerk.organizationMembership?.roleName,
///           onManageOrganization: { presentedSheet = .profile },
///           onSwitchAccount: { presentedSheet = .accountList }
///         )
///       case .accountList:
///         OrganizationListView()
///       case .profile:
///         OrganizationProfileView()
///       }
///     }
///   }
///
///   enum PresentedSheet: Hashable, Identifiable {
///     case overview(Organization)
///     case accountList
///     case profile
///
///     var id: Self {
///       self
///     }
///   }
/// }
/// ```
public struct OrganizationSwitcherSheet: View {
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss

  private let organization: Organization
  private let roleName: String?
  private let onManageOrganization: () -> Void
  private let onSwitchAccount: () -> Void

  @State private var contentHeight: CGFloat = 220

  /// Creates an organization switcher sheet.
  ///
  /// - Parameters:
  ///   - organization: The active organization to display.
  ///   - roleName: The current user's role name in the active organization.
  ///   - onManageOrganization: Called when the manage organization action is selected.
  ///   - onSwitchAccount: Called when the switch account action is selected.
  public init(
    organization: Organization,
    roleName: String?,
    onManageOrganization: @escaping () -> Void,
    onSwitchAccount: @escaping () -> Void
  ) {
    self.organization = organization
    self.roleName = roleName
    self.onManageOrganization = onManageOrganization
    self.onSwitchAccount = onSwitchAccount
  }

  public var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 0) {
          organizationRow
          Divider()

          Button {
            onManageOrganization()
          } label: {
            UserProfileRowView(icon: "icon-cog", text: "Manage")
          }
          .buttonStyle(.pressedBackground)
          Divider()

          Button {
            onSwitchAccount()
          } label: {
            UserProfileRowView(icon: "icon-switch", text: "Switch account")
          }
          .buttonStyle(.pressedBackground)

          SecuredByClerkFooter(showBackground: false)
        }
        .onGeometryChange(
          for: CGFloat.self,
          of: { proxy in
            proxy.size.height
          },
          action: { newValue in
            contentHeight = newValue + UITabBarController().tabBar.frame.size.height
          }
        )
      }
      .scrollBounceBehavior(.basedOnSize)
      .navigationBarTitleDisplayMode(.inline)
      .preGlassSolidNavBar()
      .preGlassDetentSheetBackground()
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            dismiss()
          } label: {
            Text("Done", bundle: .module)
              .font(theme.fonts.body)
              .fontWeight(.semibold)
              .foregroundStyle(theme.colors.primary)
          }
        }

        ToolbarItem(placement: .principal) {
          Text("Organization", bundle: .module)
            .font(theme.fonts.headline)
            .foregroundStyle(theme.colors.foreground)
        }
      }
    }
    .presentationDetents([.height(contentHeight)])
  }

  private var organizationRow: some View {
    HStack(spacing: 16) {
      OrganizationAvatarView(name: organization.name, imageUrl: organization.imageUrl)

      VStack(alignment: .leading, spacing: 4) {
        Text(verbatim: organization.name)
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.foreground)
          .frame(minHeight: 22, alignment: .leading)
          .lineLimit(1)

        if let roleName {
          Text(verbatim: roleName)
            .font(theme.fonts.subheadline)
            .foregroundStyle(theme.colors.mutedForeground)
            .frame(minHeight: 20, alignment: .leading)
            .lineLimit(1)
        }
      }

      Spacer()
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
    .contentShape(Rectangle())
  }
}

#Preview("Organization Overview") {
  OrganizationSwitcherSheet(
    organization: .mock,
    roleName: "Admin",
    onManageOrganization: {},
    onSwitchAccount: {}
  )
  .environment(\.clerkTheme, .clerk)
}

#endif
