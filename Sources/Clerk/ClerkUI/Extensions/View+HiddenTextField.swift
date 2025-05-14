//
//  HiddenTextField.swift
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

    func body(content: Content) -> some View {
      content
        .background {
          SecureField("", text: $text)
            .textContentType(textContentType)
            .opacity(0.00001)
            .offset(y: -50)
            .disabled(true)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
        }
    }

  }

  extension View {
    public func hiddenTextField(text: Binding<String>, textContentType: UITextContentType) -> some View {
      modifier(HiddenTextFieldModifier(text: text, textContentType: textContentType))
    }
  }

#endif
