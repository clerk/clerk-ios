//
//  OrDivider.swift
//
//
//  Created by Mike Pitre on 11/2/23.
//

#if canImport(UIKit)

import SwiftUI

struct TextDivider: View {
    @Environment(\.clerkTheme) private var clerkTheme
    
    let text: String?
    
    var body: some View {
        HStack {
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(clerkTheme.colors.borderPrimary)
            
            if let text {
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(clerkTheme.colors.textSecondary)
                    .frame(minHeight: ClerkStyleConstants.textMinHeight)
                    .layoutPriority(1)
                
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(clerkTheme.colors.borderPrimary)
            }
        }
    }
}

#Preview {
    TextDivider(text: "or, sign in with another method")
        .padding()
}

#endif
