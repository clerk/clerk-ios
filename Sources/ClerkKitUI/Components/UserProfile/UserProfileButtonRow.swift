//
//  UserProfileButtonRow.swift
//  Clerk
//
//  Created by Mike Pitre on 5/12/25.
//

#if os(iOS)

import SwiftUI

struct UserProfileButtonRow: View {
  @Environment(\.clerkTheme) private var theme

  enum Style {
    case `default`
    case danger
  }

  var foregroundColor: Color {
    switch style {
    case .default:
      theme.colors.primary
    case .danger:
      theme.colors.danger
    }
  }

  let text: LocalizedStringKey
  var style = Style.default
  let action: () async -> Void

  var body: some View {
    AsyncButton {
      await action()
    } label: { isRunning in
      Text(text, bundle: .module)
        .font(theme.fonts.body)
        .fontWeight(.semibold)
        .frame(minHeight: 22)
        .foregroundStyle(foregroundColor)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .contentShape(.rect)
        .overlayProgressView(isActive: isRunning)
    }
    .overlay(alignment: .bottom) {
      Rectangle()
        .frame(height: 1)
        .foregroundStyle(theme.colors.border)
    }
    .buttonStyle(.pressedBackground)
    .simultaneousGesture(TapGesture())
  }
}

#Preview {
  UserProfileButtonRow(text: "Add email address") {
    try! await Task.sleep(for: .seconds(1))
  }
  .environment(\.clerkTheme, .clerk)
}

#endif
