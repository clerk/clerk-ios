//
//  UserProfileRowView.swift
//  Clerk
//

#if os(iOS)

import Foundation
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
      iconImage
        .resizable()
        .scaledToFit()
        .frame(width: 48, height: 24)
        .foregroundStyle(theme.colors.mutedForeground)
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

  private var iconImage: Image {
    switch icon {
    case .asset(let name):
      Image(name, bundle: bundle)
    case .system(let name):
      Image(systemName: name)
    }
  }
}

#Preview {
  UserProfileRowView(icon: "icon-switch", text: "Switch account")
}

#endif
