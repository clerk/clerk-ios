//
//  OrganizationSwitcherSheet.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct OrganizationSwitcherSheet: View {
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss

  private let organization: Organization
  private let roleName: String?
  private let onManageOrganization: () -> Void
  private let onSwitchAccount: () -> Void

  @State private var contentHeight: CGFloat = 220

  init(
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

  var body: some View {
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
