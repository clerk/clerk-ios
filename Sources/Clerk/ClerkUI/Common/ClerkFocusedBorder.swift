//
//  ClerkFocusedBorder.swift
//  Clerk
//
//  Created by Mike Pitre on 4/18/25.
//

#if canImport(SwiftUI)

import SwiftUI

struct ClerkFocusedBorder: ViewModifier {
  @Environment(\.clerkTheme) private var theme
  
  let isFocused: Bool
  
  func body(content: Content) -> some View {
    content
      .animation(.default, body: { content in
        content
          .overlay {
            RoundedRectangle(cornerRadius: theme.design.borderRadius)
              .strokeBorder(
                isFocused ? theme.colors.inputBorderFocused : theme.colors.inputBorder,
                lineWidth: 1
              )
          }
          .background {
            RoundedRectangle(cornerRadius: theme.design.borderRadius)
              .stroke(
                theme.colors.inputBorder,
                lineWidth: isFocused ? 4 : 0
              )
          }
      })
  }
}

extension View {
  func clerkFocusedBorder(isFocused: Bool = true) -> some View {
    modifier(ClerkFocusedBorder(isFocused: isFocused))
  }
}

#Preview {
  @Previewable @Environment(\.clerkTheme) var theme
  
  RoundedRectangle(cornerRadius: theme.design.borderRadius)
    .fill(theme.colors.background)
    .frame(maxWidth: .infinity, maxHeight: 48)
    .clerkFocusedBorder()
    .padding()
}

#endif
