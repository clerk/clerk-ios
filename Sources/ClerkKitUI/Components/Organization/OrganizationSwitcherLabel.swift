//
//  OrganizationSwitcherLabel.swift
//

#if os(iOS)

import ClerkKit
import NukeUI
import SwiftUI

struct OrganizationSwitcherLabel: View {
  @Environment(\.clerkTheme) private var theme

  let organization: Organization?
  let user: User?

  var body: some View {
    HStack(spacing: 8) {
      image

      Text(verbatim: title)
        .font(theme.fonts.body)
        .fontWeight(.semibold)
        .foregroundStyle(theme.colors.foreground)
        .lineLimit(1)

      Image(systemName: "chevron.down")
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(theme.colors.mutedForeground)
    }
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder
  private var image: some View {
    if let organization {
      OrganizationAvatarView(name: organization.name, imageUrl: organization.imageUrl, size: 24)
    } else if let user {
      LazyImage(url: URL(string: user.imageUrl)) { state in
        if let image = state.image {
          image
            .resizable()
            .scaledToFill()
        } else {
          Circle().fill(theme.colors.primary.gradient)
        }
      }
      .frame(width: 24, height: 24)
      .clipShape(.circle)
    } else {
      Image(systemName: "building.2")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(theme.colors.primaryForeground)
        .frame(width: 24, height: 24)
        .background(theme.colors.primary.gradient, in: RoundedRectangle(cornerRadius: theme.design.borderRadius))
    }
  }

  private var title: String {
    if let organization {
      organization.name
    } else if user != nil {
      String(localized: "Personal account", bundle: .module)
    } else {
      String(localized: "Select organization", bundle: .module)
    }
  }
}

#Preview("Organization Switcher Label") {
  VStack(alignment: .leading, spacing: 16) {
    OrganizationSwitcherLabel(organization: .mock, user: nil)
    OrganizationSwitcherLabel(organization: nil, user: .mock)
    OrganizationSwitcherLabel(organization: nil, user: nil)
  }
  .padding()
  .environment(\.clerkTheme, .clerk)
}

#endif
