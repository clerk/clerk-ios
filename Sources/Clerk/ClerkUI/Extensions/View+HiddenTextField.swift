//
//  View+HiddenTextField.swift
//  Clerk
//
//  Created by Mike Pitre on 5/14/25.
//

#if os(iOS)

import Foundation
import SwiftUI

// Apple uses heuristics to determine when to show the save to
// keychain prompt based on present textfield content types.
// This means we often need to "fake" having a certain textfields
// in the view, in order for the prompt to appear when they disappear.
struct HiddenTextFieldModifier: ViewModifier {
  @Binding var text: String
  let textContentType: UITextContentType
  let isSecure: Bool

  func body(content: Content) -> some View {
    content
      .background {
        field
          .textContentType(textContentType)
          .opacity(0.00001)
          .offset(y: -100)
          .disabled(true)
          .accessibilityHidden(true)
          .allowsHitTesting(false)
      }
  }

  @ViewBuilder
  var field: some View {
    if isSecure {
      SecureField("", text: $text)
    } else {
      TextField("", text: $text)
    }
  }
}

public extension View {
  func hiddenTextField(text: Binding<String>, textContentType: UITextContentType, isSecure: Bool = false) -> some View {
    modifier(HiddenTextFieldModifier(text: text, textContentType: textContentType, isSecure: isSecure))
  }
}

#endif
