//
//  CustomTextField.swift
//
//
//  Created by Mike Pitre on 9/22/23.
//

#if os(iOS)

import SwiftUI

struct CustomTextField: View {
    @FocusState private var isFocused: Bool
    @Environment(\.clerkTheme) private var clerkTheme
    
    @Binding var text: String
    var placeholder: String = ""
    var isSecureField: Bool = false
    
    var body: some View {
        inputField
            .frame(minHeight: 30)
            .focused($isFocused)
            .font(.footnote)
            .padding(.horizontal)
            .tint(clerkTheme.colors.textPrimary)
            .background()
            .clipShape(.rect(cornerRadius: 6, style: .continuous))
            .shadow(color: Color(red: 0.1, green: 0.11, blue: 0.13).opacity(0.06), radius: 0.5, x: 0, y: 1)
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isFocused ? clerkTheme.colors.textPrimary : clerkTheme.colors.borderPrimary, lineWidth: 1)
            }
    }
    
    @ViewBuilder 
    private var inputField: some View {
        if isSecureField {
            SecureField(placeholder, text: $text)
        } else {
            TextField(placeholder, text: $text)
        }
    }
}

#Preview {
    CustomTextField(text: .constant("Some Text"))
        .padding()
}

#endif
