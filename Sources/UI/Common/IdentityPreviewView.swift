//
//  IdentityPreviewView.swift
//
//
//  Created by Mike Pitre on 10/10/23.
//

#if canImport(UIKit)

import SwiftUI
import PhoneNumberKit

struct IdentityPreviewView: View {
    @Environment(\.clerkTheme) private var clerkTheme
    
    var imageUrl: String?
    var label: String?
    var action: (() -> Void)?
    
    private let phoneNumberKit = PhoneNumberKit()
    
    var body: some View {
        HStack(spacing: 4) {
            if let label {
                Text(label)
                    .font(.footnote.weight(.medium))
            }
            
            if let action {
                Button(action: {
                    action()
                }, label: {
                    Image(systemName: "pencil")
                        .bold()
                })
            }
        }
        .foregroundStyle(clerkTheme.colors.gray500)
    }
}

#Preview {
    IdentityPreviewView(
        imageUrl: "",
        label: "clerkuser@gmail.com",
        action: {}
    )
}

#endif
