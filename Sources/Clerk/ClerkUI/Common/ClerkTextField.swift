//
//  ClerkTextField.swift
//  Clerk
//
//  Created by Mike Pitre on 4/10/25.
//

#if os(iOS)

import SwiftUI

struct ClerkTextField: View {
  @Environment(\.clerkTheme) private var theme
  @State private var reservedHeight: CGFloat?
  @State private var revealText = false
  @FocusState private var focused: Field?
  
  enum Field {
    case regular, secure
  }

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
    focused != nil || !text.isEmpty
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
            .foregroundStyle(theme.colors.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(0)

          ZStack {
            SecureField("", text: $text)
              .focused($focused, equals: .secure)
              .animation(.default) {
                $0.opacity(isSecure && !revealText ? 1 : 0)
              }
            TextField("", text: $text)
              .focused($focused, equals: .regular)
              .animation(.default) {
                $0.opacity(!isSecure || revealText ? 1 : 0)
              }
          }
          .lineLimit(1)
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.inputText)
          .frame(minHeight: 22)
          .tint(theme.colors.primary)
          .animation(.default.delay(0.2)) {
            $0.opacity(isFocusedOrFilled ? 1 : 0)
          }
        }
        .onGeometryChange(for: CGFloat.self) { geometry in
          geometry.size.height
        } action: { newValue in
          reservedHeight = newValue
        }

        Text(titleKey, bundle: .module)
          .lineLimit(1)
          .minimumScaleFactor(0.75)
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.textSecondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .allowsHitTesting(false)
          .offset(y: isFocusedOrFilled ? -offsetAmount : 0)
          .scaleEffect(isFocusedOrFilled ? (12 / 17) : 1, anchor: .topLeading)
          .animation(.default, value: isFocusedOrFilled)
      }

      if isSecure {
        Button {
          revealText.toggle()
          if focused == .regular {
            focused = .secure
          } else if focused == .secure {
            focused = .regular
          }
        } label: {
          Image(systemName: revealText ? "eye.fill" : "eye.slash.fill")
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
      if isSecure {
        focused =  revealText ? .regular : .secure
      } else {
        focused = .regular
      }
    }
    .background(
      theme.colors.inputBackground,
      in: .rect(cornerRadius: theme.design.borderRadius)
    )
    .clerkFocusedBorder(isFocused: focused != nil)
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

#endif
