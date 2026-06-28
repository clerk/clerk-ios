//
//  ProfileHeaderView.swift
//

#if os(iOS) || os(macOS)

import ClerkKit
import NukeUI
import SwiftUI

struct ProfileHeaderView<AvatarPlaceholder: View>: View {
  @Environment(\.clerkTheme) private var theme

  let imageUrl: String
  let title: String?
  let subtitle: String?
  let actionTitle: LocalizedStringKey?
  let action: (() -> Void)?
  let avatarCornerRadius: CGFloat?
  let avatarPlaceholder: AvatarPlaceholder

  private let avatarSize: CGFloat = 96

  init(
    imageUrl: String,
    title: String?,
    subtitle: String? = nil,
    actionTitle: LocalizedStringKey? = nil,
    action: (() -> Void)? = nil,
    avatarCornerRadius: CGFloat? = nil,
    @ViewBuilder avatarPlaceholder: () -> AvatarPlaceholder
  ) {
    self.imageUrl = imageUrl
    self.title = title
    self.subtitle = subtitle
    self.actionTitle = actionTitle
    self.action = action
    self.avatarCornerRadius = avatarCornerRadius
    self.avatarPlaceholder = avatarPlaceholder()
  }

  var body: some View {
    VStack(spacing: 12) {
      avatar

      VStack(spacing: 0) {
        if let title, !title.isEmptyTrimmed {
          Text(verbatim: title)
            .font(theme.fonts.title2)
            .fontWeight(.bold)
            .frame(minHeight: 28)
            .foregroundStyle(theme.colors.foreground)
            .multilineTextAlignment(.center)
        }

        if let subtitle, !subtitle.isEmptyTrimmed {
          Text(verbatim: subtitle)
            .font(theme.fonts.subheadline)
            .foregroundStyle(theme.colors.mutedForeground)
        }
      }

      if let actionTitle, let action {
        Button {
          action()
        } label: {
          Text(actionTitle, bundle: .module)
        }
        .buttonStyle(.secondary(config: .init(size: .small)))
        .simultaneousGesture(TapGesture())
      }
    }
    .padding(32)
    .frame(maxWidth: .infinity)
  }

  private var avatar: some View {
    LazyImage(url: URL(string: imageUrl)) { state in
      if let image = state.image {
        image
          .resizable()
          .scaledToFill()
      } else {
        avatarPlaceholder
      }
    }
    .frame(width: avatarSize, height: avatarSize)
    .clipShape(.rect(cornerRadius: avatarCornerRadius ?? avatarSize / 2))
    .transition(.opacity.animation(.easeInOut(duration: 0.25)))
  }
}

#Preview("Profile Header") {
  ProfileHeaderView(
    imageUrl: "",
    title: "Clerk Sample Apps",
    subtitle: "username",
    actionTitle: "Update profile",
    action: {}
  ) {
    Circle()
      .fill(.blue.gradient)
  }
  .environment(\.clerkTheme, .clerk)
}

#endif
