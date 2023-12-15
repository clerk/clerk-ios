//
//  CustomTextField.swift
//
//
//  Created by Mike Pitre on 9/22/23.
//

#if canImport(UIKit)

import SwiftUI

struct CustomTextField: View {
    @FocusState private var isFocused: Bool
    @Environment(\.clerkTheme) private var clerkTheme
    
    @Binding var text: String
    var isSecureField: Bool = false
    
    var body: some View {
        inputField
            .frame(maxHeight: .infinity)
            .focused($isFocused)
            .font(.subheadline)
            .padding(.horizontal)
            .tint(clerkTheme.colors.textPrimary)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isFocused ? clerkTheme.colors.textPrimary : Color(.systemFill), lineWidth: 1)
            }
    }
    
    @ViewBuilder 
    private var inputField: some View {
        if isSecureField {
            SecureField("", text: $text)
        } else {
            TextField("", text: $text)
        }
    }
}

#Preview {
    CustomTextField(text: .constant(""))
        .frame(height: 44)
        .padding()
}

#endif
