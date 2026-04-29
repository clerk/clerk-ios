//
//  OrganizationSwitcherSummaryView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct OrganizationSwitcherSummaryView: View {
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss

  let organization: Organization
  let roleName: String?
  @Binding var contentHeight: CGFloat
  let onManageOrganization: ((Organization) -> Void)?
  let onSwitchAccount: () -> Void

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 0) {
          organizationRow
          Divider()

          if let onManageOrganization {
            Button {
              dismiss()
              onManageOrganization(organization)
            } label: {
              UserProfileRowView(icon: "icon-cog", text: "Manage")
            }
            .buttonStyle(.pressedBackground)
            Divider()
          }

          Button {
            onSwitchAccount()
          } label: {
            UserProfileRowView(icon: "icon-switch", text: "Switch account")
          }
          .buttonStyle(.pressedBackground)
          Divider()

          SecuredByClerkView()
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
        .navigationBarTitleDisplayMode(.inline)
        .preGlassSolidNavBar()
        .preGlassDetentSheetBackground()
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
              dismiss()
            }
            .foregroundStyle(theme.colors.primary)
          }

          ToolbarItem(placement: .principal) {
            Text("Organization", bundle: .module)
              .font(theme.fonts.headline)
              .foregroundStyle(theme.colors.foreground)
          }
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
    }
  }

  private var organizationRow: some View {
    HStack(spacing: 16) {
      OrganizationAvatarView(name: organization.name, imageUrl: organization.imageUrl, size: 48)

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

#Preview("Organization Summary") {
  OrganizationSwitcherSummaryView(
    organization: .mock,
    roleName: "Admin",
    contentHeight: .constant(220),
    onManageOrganization: { _ in },
    onSwitchAccount: {}
  )
  .environment(\.clerkTheme, .clerk)
}

#endif
