//
//  PasswordInputView.swift
//
//
//  Created by Mike Pitre on 11/1/23.
//

#if canImport(SwiftUI)

import SwiftUI

struct PasswordInputView: View {
    @Binding var password: String
    
    var body: some View {
        CustomTextField(text: $password, isSecureField: true)
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
