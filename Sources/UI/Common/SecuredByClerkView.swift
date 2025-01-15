//
//  SecuredByClerkView.swift
//
//
//  Created by Mike Pitre on 11/29/23.
//

#if os(iOS)

import SwiftUI

struct SecuredByClerkView: View {
    @Environment(ClerkTheme.self) private var clerkTheme
    
    var body: some View {
        HStack(spacing: 4) {
            Text("Secured by ")
                .font(.footnote)
                .foregroundStyle(clerkTheme.colors.textSecondary)
            HStack(spacing: 0) {
                Image("clerk-logomark-gray", bundle: .module)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                Image("clerk-name-gray", bundle: .module)
                    .renderingMode(.template)
            }
            .font(.subheadline)
        }
        .foregroundStyle(clerkTheme.colors.textSecondary.opacity(0.7))
    }
}

#Preview {
    SecuredByClerkView()
}

#endif
