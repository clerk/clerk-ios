//
//  UserProfilePasskeyView.swift
//  Clerk
//
//  Created by Mike Pitre on 9/9/24.
//

#if os(iOS)

import SwiftUI

struct UserProfilePasskeyView: View {
    @Environment(\.clerkTheme) private var clerkTheme
    
    let passkey: Passkey
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(passkey.name)
                .font(.footnote.weight(.medium))
            
            Group {
                Text("Created: " + passkey.createdAt.formatted(Date.RelativeFormatStyle()))
                if let lastUsedAt = passkey.lastUsedAt {
                    Text("Last used: " + lastUsedAt.formatted(Date.RelativeFormatStyle()))
                }
            }
            .foregroundStyle(clerkTheme.colors.textSecondary)
            .font(.footnote)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    UserProfilePasskeyView(passkey: .mock)
}

#endif
