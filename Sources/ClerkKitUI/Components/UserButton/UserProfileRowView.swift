//
//  UserProfileRowView.swift
//  Clerk
//

#if os(iOS)

import SwiftUI

struct UserProfileRowView: View {
  @Environment(\.clerkTheme) private var theme

  let icon: UserProfileRowIcon
  let text: LocalizedStringKey
  let bundle: Bundle?

  init(icon: UserProfileRowIcon, text: LocalizedStringKey, bundle: Bundle? = .module) {
    self.icon = icon
    self.text = text
    self.bundle = bundle
  }

  init(icon: String, text: LocalizedStringKey, bundle: Bundle? = .module) {
    self.init(icon: .asset(name: icon), text: text, bundle: bundle)
  }

  var body: some View {
    HStack(spacing: 16) {
      iconView
      Text(text, bundle: bundle)
        .font(theme.fonts.body)
        .fontWeight(.semibold)
        .foregroundStyle(theme.colors.foreground)
        .frame(minHeight: 22)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 16)
    .padding(.horizontal, 24)
    .contentShape(.rect)
  }

  @ViewBuilder
  private var iconView: some View {
    switch icon {
    case .asset(let name, let width, let height):
      Image(name, bundle: bundle)
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .frame(width: width, height: height)
        .frame(width: 48, height: 24)
        .foregroundStyle(theme.colors.mutedForeground)
    case .system(let name):
      Image(systemName: name)
        .resizable()
        .scaledToFit()
        .frame(maxWidth: 21, maxHeight: 21)
        .frame(width: 48, height: 24)
        .foregroundStyle(theme.colors.mutedForeground)
    }
  }
}

#Preview {
  UserProfileRowView(icon: "icon-switch", text: "Switch account")
}

#endif
