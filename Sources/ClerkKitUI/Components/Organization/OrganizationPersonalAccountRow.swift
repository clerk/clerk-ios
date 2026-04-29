//
//  OrganizationPersonalAccountRow.swift
//

#if os(iOS)

import ClerkKit
import NukeUI
import SwiftUI

struct OrganizationPersonalAccountRow<Accessory: View>: View {
  @Environment(\.clerkTheme) private var theme

  let user: User
  let subtitle: Text?
  let accessory: Accessory

  init(
    user: User,
    subtitle: Text? = Text("Personal account", bundle: .module),
    @ViewBuilder accessory: () -> Accessory
  ) {
    self.user = user
    self.subtitle = subtitle
    self.accessory = accessory()
  }

  var body: some View {
    HStack(spacing: 16) {
      LazyImage(url: URL(string: user.imageUrl)) { state in
        if let image = state.image {
          image
            .resizable()
            .scaledToFill()
        } else {
          Rectangle().fill(theme.colors.primary.gradient)
        }
      }
      .frame(width: 48, height: 48)
      .clipShape(.circle)

      VStack(alignment: .leading, spacing: 4) {
        Text(verbatim: title)
          .font(.body)
          .foregroundStyle(theme.colors.foreground)
          .lineLimit(1)

        if let subtitle {
          subtitle
            .font(.subheadline)
            .foregroundStyle(theme.colors.mutedForeground)
            .lineLimit(1)
        }
      }

      Spacer()

      accessory
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 16)
    .contentShape(Rectangle())
  }

  private var title: String {
    user.fullName ?? user.identifier ?? String(localized: "Personal account", bundle: .module)
  }
}

extension OrganizationPersonalAccountRow where Accessory == EmptyView {
  init(user: User, subtitle: Text? = Text("Personal account", bundle: .module)) {
    self.init(user: user, subtitle: subtitle) {
      EmptyView()
    }
  }
}

#Preview {
  OrganizationPersonalAccountRow(user: .mock) {
    OrganizationSelectedAccessory()
  }
  .environment(\.clerkTheme, .clerk)
}

#endif
