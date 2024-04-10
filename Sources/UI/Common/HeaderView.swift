//
//  HeaderView.swift
//
//
//  Created by Mike Pitre on 11/2/23.
//

#if canImport(SwiftUI)

import SwiftUI

struct HeaderView: View {
    @Environment(\.clerkTheme) private var clerkTheme
    
    let title: String
    var subtitle: String?
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.body.weight(.bold))
                .frame(minHeight: 24)
            
            if let subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(clerkTheme.colors.textSecondary)
            }
        }
    }
}

#Preview {
    HeaderView(
        title: "Create your account",
        subtitle: "to continue to Test"
    )
    .padding()
}

#endif
