//
//  PasswordInputView.swift
//
//
//  Created by Mike Pitre on 11/1/23.
//

#if canImport(UIKit)

import SwiftUI

struct PasswordInputView: View {
    @Binding var password: String
    
    var body: some View {
        CustomTextField(text: $password, isSecureField: true)
            .frame(height: 38)
            .textContentType(.newPassword)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
    }
}

#Preview {
    PasswordInputView(password: .constant(""))
        .padding()
}

#endif
