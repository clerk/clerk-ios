//
//  HiddenTextField.swift
//
//
//  Created by Mike Pitre on 8/22/24.
//

#if os(iOS)

import Foundation
import SwiftUI

struct HiddenTextFieldModifier: ViewModifier {
    
    @Binding var text: String
    let textContentType: UITextContentType
    
    func body(content: Content) -> some View {
        content
            .background {
                SecureField("", text: $text)
                    .textContentType(textContentType)
                    .opacity(0.00001)
                    .disabled(true)
                    .accessibilityHidden(true)
            }
    }
    
}

extension View {
    /// Apple uses heuristics to determine when to show the save to
    /// keychain prompt based on present textfield content types.
    /// This mean we often need to "fake" having a certain textfields
    /// in the view, in order for the prompt to appear when they disappear.
    public func hiddenTextField(text: Binding<String>, textContentType: UITextContentType) -> some View {
        modifier(HiddenTextFieldModifier(text: text, textContentType: textContentType))
    }
}

#endif
