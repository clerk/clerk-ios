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
  @State private var reservedHeight: CGFloat?
  @State private var revealText = false

  let titleKey: LocalizedStringKey
  @Binding var text: String
  let isSecure: Bool

  init(
    _ titleKey: LocalizedStringKey,
    text: Binding<String>,
    isSecure: Bool = false
  ) {
    self.titleKey = titleKey
    self._text = text
    self.isSecure = isSecure
  }

  var isFocusedOrFilled: Bool {
    isFocused || !text.isEmpty
  }
  
  var offsetAmount: CGFloat {
    guard let reservedHeight else { return 0 }
    return reservedHeight * 0.333
  }

  var body: some View {
    HStack(spacing: 8) {
      ZStack(alignment: .leading) {
        VStack(alignment: .leading, spacing: 2) {
          Text(titleKey, bundle: .module)
            .lineLimit(1)
            .font(theme.fonts.caption)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(0)

          Group {
            if isSecure && !revealText {
              SecureField("", text: $text)
            } else {
              TextField("", text: $text)
            }
          }
          .focused($isFocused)
          .lineLimit(1)
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.inputText)
          .frame(minHeight: 22)
          .tint(theme.colors.primary)
          .transition(.opacity.animation(.default))
        }
        .onGeometryChange(for: CGFloat.self) { geometry in
          geometry.size.height
        } action: { newValue in
          reservedHeight = newValue
        }

        Text(titleKey, bundle: .module)
          .lineLimit(1)
          .font(theme.fonts.body)
          .frame(maxWidth: .infinity, alignment: .leading)
          .foregroundStyle(theme.colors.textSecondary)
          .allowsHitTesting(false)
          .offset(y: isFocusedOrFilled ? -offsetAmount : 0)
          .scaleEffect(isFocusedOrFilled ? (12/17) : 1, anchor: .topLeading)
      }
      
      if isSecure {
        Button {
          revealText.toggle()
        } label: {
          Image(systemName: revealText ? "eye.slash.fill" : "eye.fill")
            .contentTransition(.symbolEffect(.replace))
            .foregroundStyle(theme.colors.textSecondary)
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 6)
    .frame(minHeight: 56)
    .contentShape(.rect)
    .onTapGesture {
      isFocused = true
    }
    .background(
      theme.colors.inputBackground,
      in: .rect(cornerRadius: theme.design.borderRadius)
    )
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
    .animation(.default, value: isFocused)
  }
}

#Preview {
  @Previewable @State var emptyEmail: String = ""
  @Previewable @State var filledEmail: String = "user@example.com"

  VStack(spacing: 20) {
    ClerkTextField("Enter your email", text: $emptyEmail)
    ClerkTextField("Enter your email", text: $filledEmail)
    ClerkTextField("Enter your password", text: $filledEmail, isSecure: true)
  }
  .padding()
}
