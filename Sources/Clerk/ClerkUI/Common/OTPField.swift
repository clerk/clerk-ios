//
//  OTPField.swift
//  Clerk
//
//  Created by Mike Pitre on 4/21/25.
//

import SwiftUI

struct OTPField: View {
  @Environment(\.clerkTheme) private var theme

  @Binding var code: String
  let numberOfInputs: Int = 6

  @FocusState private var isFocused: Bool
  @State private var cursorAnimating = false
  @State private var inputSize = CGSize.zero

  var body: some View {
    HStack(spacing: 12) {
      ForEach(0..<numberOfInputs, id: \.self) { index in
        otpFieldInput(index: index)
      }
    }
    .overlay {
      TextField("", text: $code.maxLength(numberOfInputs))
        .textContentType(.oneTimeCode)
        .keyboardType(.numberPad)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.clear)
        .tint(.clear)
        .focused($isFocused)
    }
    .contentShape(.rect)
    .onFirstAppear {
      isFocused = true
    }
  }

  @ViewBuilder
  func otpFieldInput(index: Int) -> some View {
    var isSelected: Bool {
      isFocused && code.count == index
    }

    ZStack {
      if code.count > index {
        let startIndex = code.startIndex
        let charIndex = code.index(startIndex, offsetBy: index)
        let charToString = String(code[charIndex])
        Text(charToString)
      } else {
        Text(" ", bundle: .module)
      }
    }
    .monospacedDigit()
    .padding(.vertical)
    .frame(maxWidth: .infinity, minHeight: 56)
    .onGeometryChange(for: CGSize.self, of: { geometry in
      geometry.size
    }, action: { newValue in
      inputSize = newValue
    })
    .overlay {
      if isSelected {
        Rectangle()
          .frame(maxWidth: 2, maxHeight: 0.35 * inputSize.height)
          .foregroundStyle(theme.colors.primary)
          .animation(.easeInOut.speed(0.75).repeatForever(), body: { content in
            content
              .opacity(cursorAnimating ? 1 : 0)
          })
          .onAppear {
            cursorAnimating.toggle()
          }
      }
    }
    .font(theme.fonts.body)
    .foregroundStyle(theme.colors.text)
    .allowsHitTesting(false)
    .background(theme.colors.inputBackground)
    .clipShape(.rect(cornerRadius: theme.design.borderRadius))
    .overlay {
      RoundedRectangle(cornerRadius: theme.design.borderRadius)
        .strokeBorder(theme.colors.inputBackground)
    }
    .clerkFocusedBorder(isFocused: isSelected)
  }
}

private extension Binding where Value == String {
  func maxLength(_ length: Int) -> Self {
    if wrappedValue.count > length {
      DispatchQueue.main.async {
        self.wrappedValue = String(wrappedValue.prefix(6))
      }
    }
    return self
  }
}

#Preview {
  @Previewable @State var code = ""
  OTPField(code: $code)
    .padding()
//    .environment(\.dynamicTypeSize, .accessibility5)
}
