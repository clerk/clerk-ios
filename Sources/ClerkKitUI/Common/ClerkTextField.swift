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

  enum FieldState {
    case `default`, error
  }

  let titleKey: LocalizedStringKey
  @Binding var text: String
  let isSecure: Bool
  let fieldState: FieldState

  init(
    _ titleKey: LocalizedStringKey,
    text: Binding<String>,
    isSecure: Bool = false,
    fieldState: FieldState = .default
  ) {
    self.titleKey = titleKey
    _text = text
    self.isSecure = isSecure
    self.fieldState = fieldState
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
            .foregroundStyle(theme.colors.foreground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(0)

          ZStack {
            TextField("", text: $text)
              .zIndex(revealText ? 1 : 0)
              .focused($focused, equals: .regular)
              .animation(.default) {
                $0.opacity(!isSecure || revealText ? 1 : 0)
              }

            if isSecure {
              SecureField("", text: $text)
                .zIndex(revealText ? 0 : 1)
                .focused($focused, equals: .secure)
                .animation(.default) {
                  $0.opacity(isSecure && !revealText ? 1 : 0)
                }
            }
          }
          .lineLimit(1)
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.inputForeground)
          .frame(minHeight: 22)
          .tint(theme.colors.primary)
          .animation(.default.delay(0.2)) {
            $0.opacity(isFocusedOrFilled ? 1 : 0.0001)
          }
          .onChange(of: focused) { _, newValue in
            if newValue != nil {
              focused = revealText ? .regular : .secure
            }
          }
          .onChange(of: revealText) { _, _ in
            if focused == .regular {
              focused = .secure
            } else if focused == .secure {
              focused = .regular
            }
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
          .foregroundStyle(theme.colors.mutedForeground)
          .frame(maxWidth: .infinity, alignment: .leading)
          .allowsHitTesting(false)
          .offset(y: isFocusedOrFilled ? -offsetAmount : 0)
          .scaleEffect(isFocusedOrFilled ? (12 / 17) : 1, anchor: .topLeading)
          .animation(.default, value: isFocusedOrFilled)
      }

      if isSecure {
        Button {
          revealText.toggle()
        } label: {
          Image(systemName: revealText ? "eye.fill" : "eye.slash.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 18)
            .contentTransition(.symbolEffect(.replace))
            .foregroundStyle(theme.colors.mutedForeground)
        }
        .frame(width: 24)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 6)
    .frame(minHeight: 56)
    .contentShape(.rect)
    .onTapGesture {
      if isSecure {
        focused = revealText ? .regular : .secure
      } else {
        focused = .regular
      }
    }
    .background(
      theme.colors.input,
      in: .rect(cornerRadius: theme.design.borderRadius)
    )
    .clerkFocusedBorder(
      isFocused: focused != nil,
      state: fieldState == .error ? .error : .default
    )
  }
}

#Preview {
  @Previewable @State var emptyEmail = ""
  @Previewable @State var filledEmail = "user@example.com"

  VStack(spacing: 20) {
    ClerkTextField("Enter your email", text: $emptyEmail)
    ClerkTextField("Enter your email", text: $filledEmail)
    ClerkTextField("Enter your password", text: $filledEmail, isSecure: true)
  }
  .padding()
}

#endif
