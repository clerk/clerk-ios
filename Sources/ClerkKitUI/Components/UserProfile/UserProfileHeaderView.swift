//
//  UserProfileHeaderView.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import NukeUI
import SwiftUI

struct UserProfileHeaderView: View {
  @Environment(\.clerkTheme) private var theme

  let user: User
  let onUpdateProfile: () -> Void

  var body: some View {
    let fullName = user.fullName
    let hasFullName = fullName != nil

    VStack(spacing: 12) {
      LazyImage(url: URL(string: user.imageUrl)) { state in
        if let image = state.image {
          image
            .resizable()
            .scaledToFill()
        } else {
          Image("icon-profile", bundle: .module)
            .resizable()
            .scaledToFit()
            .foregroundStyle(theme.colors.primary.gradient)
            .opacity(0.5)
        }
      }
      .frame(width: 96, height: 96)
      .clipShape(.circle)
      .transition(.opacity.animation(.easeInOut(duration: 0.25)))

      VStack(spacing: 0) {
        if let fullName {
          Text(fullName)
            .font(theme.fonts.title2)
            .fontWeight(.bold)
            .frame(minHeight: 28)
            .foregroundStyle(theme.colors.foreground)
        }

        if let username = user.username, !username.isEmptyTrimmed {
          Text(username)
            .font(
              hasFullName
                ? theme.fonts.subheadline
                : theme.fonts.title2
            )
            .fontWeight(hasFullName ? .regular : .bold)
            .frame(minHeight: hasFullName ? nil : 28)
            .foregroundStyle(hasFullName ? theme.colors.mutedForeground : theme.colors.foreground)
        }
      }

      Button {
        onUpdateProfile()
      } label: {
        Text("Edit profile", bundle: .module)
      }
      .buttonStyle(.secondary(config: .init(size: .small)))
      .simultaneousGesture(TapGesture())
    }
    .padding(32)
    .frame(maxWidth: .infinity)
  }
}

#endif
