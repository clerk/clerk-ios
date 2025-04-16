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
    ZStack(alignment: .leading) {
      VStack(alignment: .leading, spacing: 2) {
        if !text.isEmpty {
          Text(titleKey, bundle: .module)
            .frame(maxWidth: .infinity, minHeight: 16, alignment: .leading)
            .font(theme.fonts.caption)
            .foregroundStyle(theme.colors.textSecondary)
        }

        TextField("", text: $text)
          .focused($isFocused)
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.inputText)
          .tint(theme.colors.neutral)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
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

      if text.isEmpty {
        Text(titleKey, bundle: .module)
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.textSecondary)
          .padding(.horizontal, 16)
          .frame(maxWidth: .infinity, alignment: .leading)
          .allowsHitTesting(false)
      }
    }
    .animation(.snappy, value: text.isEmpty)
  }
}

#Preview {
  @Previewable @State var emptyEmail: String = ""
  @Previewable @State var filledEmail: String = "user@example.com"

  VStack(spacing: 20) {
    ClerkTextField("Enter your email", text: $emptyEmail)
    ClerkTextField("Enter your email", text: $filledEmail)
  }
  .padding()
}
