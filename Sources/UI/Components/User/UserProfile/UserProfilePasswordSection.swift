//
//  UserProfilePasswordSection.swift
//
//
//  Created by Mike Pitre on 11/27/23.
//

#if canImport(UIKit)

import SwiftUI

struct UserProfilePasswordSection: View {
    @Environment(\.clerkTheme) private var clerkTheme
    @State private var changePasswordIsPresented = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            UserProfileSectionHeader(title: "Password")
            Text("••••••••••")
                .font(.footnote.weight(.medium))
            Button("Change password", systemImage: "pencil") {
                changePasswordIsPresented = true
            }
            .font(.footnote.weight(.medium))
            .tint(clerkTheme.colors.textPrimary)
            .sheet(isPresented: $changePasswordIsPresented, content: {
                UserProfileChangePasswordView()
            })
        }
    }
}

#Preview {
    UserProfilePasswordSection()
        .padding()
}

#endif
