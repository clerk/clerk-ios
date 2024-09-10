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
    @State private var renameIsPresented = false
    
    let passkey: Passkey
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading) {
                Text(passkey.name)
                    .font(.footnote.weight(.medium))
                
                Group {
                    Text("Created: " + passkey.createdAt.formatted(Date.RelativeFormatStyle(presentation: .named)))
                    if let lastUsedAt = passkey.lastUsedAt {
                        Text("Last used: " + lastUsedAt.formatted(Date.RelativeFormatStyle(presentation: .named)))
                    }
                }
                .foregroundStyle(clerkTheme.colors.textSecondary)
                .font(.footnote)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            Menu {
                AsyncButton {
                    renameIsPresented = true
                } label: {
                    Text("Rename")
                }
                
                AsyncButton(role: .destructive) {
                    //
                } label: {
                    Text("Remove")
                }

            } label: {
                MoreActionsView()
            }
            .tint(clerkTheme.colors.textPrimary)
        }
        .sheet(isPresented: $renameIsPresented, content: {
            UserProfilePasskeyRenameView(passkey: passkey)
        })
    }
}

#Preview {
    UserProfilePasskeyView(passkey: .mock)
        .padding()
}

#endif
