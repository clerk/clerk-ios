//
//  OrganizationProfileHeaderView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct OrganizationProfileHeaderView: View {
  @Environment(\.clerkTheme) private var theme

  let organization: Organization
  let showsUpdateProfile: Bool
  let onUpdateProfile: () -> Void

  private var initials: String {
    String(organization.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
  }

  var body: some View {
    ProfileHeaderView(
      imageUrl: organization.imageUrl,
      title: organization.name,
      actionTitle: showsUpdateProfile ? "Update profile" : nil,
      action: showsUpdateProfile ? onUpdateProfile : nil,
      avatarPlaceholder: {
        initialsAvatar
      }
    )
  }

  private var initialsAvatar: some View {
    ZStack {
      Circle()
        .fill(theme.colors.primary.gradient)

      if initials.isEmpty {
        Image(systemName: "building.2")
          .font(.system(size: 34, weight: .semibold))
          .foregroundStyle(theme.colors.primaryForeground)
      } else {
        Text(verbatim: initials)
          .font(.system(size: 36, weight: .semibold))
          .foregroundStyle(theme.colors.primaryForeground)
      }
    }
  }
}

#Preview("Organization Profile Header") {
  OrganizationProfileHeaderView(
    organization: .mock,
    showsUpdateProfile: true,
    onUpdateProfile: {}
  )
  .environment(\.clerkTheme, .clerk)
}

#endif
