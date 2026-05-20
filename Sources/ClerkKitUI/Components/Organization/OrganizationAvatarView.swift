//
//  OrganizationAvatarView.swift
//

#if os(iOS)

import NukeUI
import SwiftUI

struct OrganizationAvatarView: View {
  @Environment(\.clerkTheme) private var theme

  let name: String
  let imageUrl: String
  var size: CGFloat = 48

  private var initials: String {
    String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
  }

  var body: some View {
    LazyImage(url: URL(string: imageUrl)) { state in
      if let image = state.image {
        image
          .resizable()
          .scaledToFill()
      } else {
        initialsView
      }
    }
    .frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: theme.design.borderRadius))
  }

  private var initialsView: some View {
    ZStack {
      RoundedRectangle(cornerRadius: theme.design.borderRadius)
        .fill(theme.colors.primary.gradient)

      Text(verbatim: initials)
        .font(.system(size: size * 0.375, weight: .semibold))
        .foregroundStyle(theme.colors.primaryForeground)
    }
  }
}

#Preview {
  OrganizationAvatarView(name: "Acme Inc.", imageUrl: "")
    .environment(\.clerkTheme, .clerk)
}

#endif
