//
//  IdentityPreviewView.swift
//
//
//  Created by Mike Pitre on 10/10/23.
//

#if os(iOS)

import SwiftUI

struct IdentityPreviewView: View {
    @Environment(ClerkTheme.self) private var clerkTheme
    
    var label: String?
    var action: (() -> Void)?
        
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
        .foregroundStyle(clerkTheme.colors.textSecondary)
    }
}

#Preview {
    IdentityPreviewView(label: "clerkuser@gmail.com")
        .environment(ClerkTheme.clerkDefault)
}

#endif
