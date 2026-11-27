//
//  UserProfileSelectedRowModifier.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import SwiftUI

struct UserProfileSelectedRowModifier: ViewModifier {
  @Environment(\.clerkTheme) private var theme

  let isSelected: Bool

  func body(content: Content) -> some View {
    content
      .background(isSelected ? theme.colors.muted : .clear)
      .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

#endif
