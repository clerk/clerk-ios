//
//  CustomTextField.swift
//
//
//  Created by Mike Pitre on 9/22/23.
//

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

#Preview {
    CustomTextField(
        title: "Email address",
        text: .constant("")
    )
}
