//
//  View+HiddenTextField.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import Foundation
import SwiftUI

#if os(iOS)
import UIKit

public typealias PlatformTextContentType = UITextContentType
#elseif os(macOS)
import AppKit

public typealias PlatformTextContentType = NSTextContentType
#endif

/// Apple uses heuristics to determine when to show the save to
/// keychain prompt based on present textfield content types.
/// This means we often need to "fake" having a certain textfields
/// in the view, in order for the prompt to appear when they disappear.
struct HiddenTextFieldModifier: ViewModifier {
  @Binding var text: String
  let textContentType: PlatformTextContentType
  let isSecure: Bool

  func body(content: Content) -> some View {
    if ClerkE2EEnvironment.isEnabled {
      content
    } else {
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

extension View {
  public func hiddenTextField(text: Binding<String>, textContentType: PlatformTextContentType, isSecure: Bool = false) -> some View {
    modifier(HiddenTextFieldModifier(text: text, textContentType: textContentType, isSecure: isSecure))
  }
}

#endif
