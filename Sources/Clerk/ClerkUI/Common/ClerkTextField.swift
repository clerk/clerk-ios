//
//  ClerkTextField.swift
//  Clerk
//
//  Created by Mike Pitre on 4/10/25.
//

import SwiftUI

struct ClerkTextField: View {
  @Environment(\.clerkTheme) private var theme
  @FocusState private var isFocused: Bool

  let titleKey: LocalizedStringKey
  @Binding var text: String

  init(_ titleKey: LocalizedStringKey, text: Binding<String>) {
    self.titleKey = titleKey
    self._text = text
  }

  var body: some View {
    TextField(
      "",
      text: $text,
      prompt: Text(
        titleKey,
        bundle: .module
      ).foregroundStyle(theme.colors.textSecondary)
    )
    .focused($isFocused)
    .font(theme.fonts.body)
    .foregroundStyle(theme.colors.inputText)
    .tint(theme.colors.neutral)
    .padding(.horizontal, 12)
    .frame(minHeight: 56)
    .background(
      theme.colors.inputBackground,
      in: .rect(cornerRadius: theme.design.borderRadius)
    )
    .overlay {
      RoundedRectangle(cornerRadius: theme.design.borderRadius)
        .strokeBorder(
          isFocused ? theme.colors.inputBorderHover : theme.colors.inputBorder,
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
    .animation(.default, value: isFocused)
  }
}

#Preview {
  VStack(spacing: 20) {
    ClerkTextField("Enter your email", text: .constant(""))
    ClerkTextField("Enter your email", text: .constant("user@example.com"))
  }
  .padding()
}
