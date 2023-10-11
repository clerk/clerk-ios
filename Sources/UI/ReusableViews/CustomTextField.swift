//
//  CustomTextField.swift
//
//
//  Created by Mike Pitre on 9/22/23.
//

#if !os(macOS)

import SwiftUI

struct CustomTextField: View {
    let title: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.medium))
            TextField("", text: $text)
                .font(.subheadline)
                .frame(height: 36)
                .padding(.horizontal)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.quaternary, lineWidth: 1)
                }
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
