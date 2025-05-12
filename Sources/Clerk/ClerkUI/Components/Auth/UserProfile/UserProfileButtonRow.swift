//
//  UserProfileButtonRow.swift
//  Clerk
//
//  Created by Mike Pitre on 5/12/25.
//

import SwiftUI

struct UserProfileButtonRow: View {
  @Environment(\.clerkTheme) private var theme
  
  let text: LocalizedStringKey
  let action: () async -> Void
  
  var body: some View {
    AsyncButton {
      await action()
    } label: { isRunning in
      Text(text, bundle: .module)
        .font(theme.fonts.body)
        .fontWeight(.semibold)
        .frame(minHeight: 22)
        .foregroundStyle(theme.colors.primary)
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
