//
//  CustomTextField.swift
//
//
//  Created by Mike Pitre on 9/22/23.
//

#if canImport(UIKit)

import SwiftUI

struct CustomTextField: View {
    let title: String
    @Binding var text: String
    var isSecureField: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.medium))
            
            inputField
                .font(.subheadline)
                .frame(height: 36)
                .padding(.horizontal)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.quaternary, lineWidth: 1)
                }
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

struct CustomTextField_Previews: PreviewProvider {
    static var previews: some View {
        CustomTextField(
            title: "Email address",
            text: .constant("")
        )
    }
}

#endif
