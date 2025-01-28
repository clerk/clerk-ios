//
//  UserProfilePasswordSection.swift
//
//
//  Created by Mike Pitre on 11/27/23.
//

#if os(iOS)

import SwiftUI

struct UserProfilePasswordSection: View {
    @Environment(ClerkTheme.self) private var clerkTheme
    @State private var changePasswordIsPresented = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Password")
                .font(.footnote.weight(.medium))
            HStack {
                Text("••••••••••")
                    .font(.title3.weight(.medium))
                Spacer()
                Button("Change password") {
                    changePasswordIsPresented = true
                }
                .font(.caption.weight(.medium))
            }
            .font(.footnote.weight(.medium))
            .tint(clerkTheme.colors.textPrimary)
            .padding(.leading, 12)
            .sheet(isPresented: $changePasswordIsPresented, content: {
                UserProfileChangePasswordView()
            })
            
            Divider()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    UserProfilePasswordSection()
        .padding()
}

#endif
