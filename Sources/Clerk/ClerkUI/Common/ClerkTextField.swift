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
  @State private var textFieldHeight: CGFloat?

  let titleKey: LocalizedStringKey
  @Binding var text: String

  init(_ titleKey: LocalizedStringKey, text: Binding<String>) {
    self.titleKey = titleKey
    self._text = text
  }
  
  var offsetAmount: CGFloat {
    guard let textFieldHeight else { return .zero }
    return textFieldHeight * 0.45
  }
  
  var isFocusedOrFilled: Bool {
    isFocused || !text.isEmpty
  }

  var body: some View {
    ZStack(alignment: .leading) {
      Text(titleKey, bundle: .module)
        .lineLimit(1)
        .font(theme.fonts.body)
        .foregroundStyle(theme.colors.textSecondary)
        .scaleEffect(isFocusedOrFilled ? (12/17) : 1, anchor: .topLeading)
        .frame(minHeight: 16)
        .padding(.top, isFocusedOrFilled ? -offsetAmount : 0)
        .frame(maxWidth: .infinity, alignment: .leading)

      TextField("", text: $text)
        .focused($isFocused)
        .lineLimit(1)
        .font(theme.fonts.body)
        .foregroundStyle(theme.colors.inputText)
        .frame(minHeight: 22)
        .padding(.top, isFocusedOrFilled ? offsetAmount : 0)
        .tint(theme.colors.primary)
        .onGeometryChange(for: CGFloat.self, of: { geometry in
          geometry.size.height
        }, action: { newValue in
          textFieldHeight = newValue
        })
    }
    .padding(.horizontal, 16)
    .padding(.vertical, isFocusedOrFilled ? 8 : 16)
    .frame(minHeight: 56)
    .background(
      theme.colors.inputBackground,
      in: .rect(cornerRadius: theme.design.borderRadius)
    )
    .overlay {
      RoundedRectangle(cornerRadius: theme.design.borderRadius)
        .stroke(
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
    .animation(.default, value: isFocusedOrFilled)
    .animation(.default, value: isFocused)
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
