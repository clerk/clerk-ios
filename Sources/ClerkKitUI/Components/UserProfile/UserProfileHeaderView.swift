//
//  UserProfileHeaderView.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct UserProfileHeaderView: View {
  @Environment(\.clerkTheme) private var theme

  let user: User
  let onUpdateProfile: () -> Void

  private var title: String? {
    user.fullName ?? user.username
  }

  private var subtitle: String? {
    guard user.fullName != nil else { return nil }
    return user.username
  }

  var body: some View {
    ProfileHeaderView(
      imageUrl: user.imageUrl,
      title: title,
      subtitle: subtitle,
      actionTitle: "Edit profile",
      action: onUpdateProfile
    ) {
      Image("icon-profile", bundle: .module)
        .resizable()
        .scaledToFit()
        .foregroundStyle(theme.colors.primary.gradient)
        .opacity(0.5)
    }
  }
}

#endif
