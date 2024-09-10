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
    @State private var confirmationSheetIsPresented = false
    @State private var errorWrapper: ErrorWrapper?
    
    let passkey: Passkey
    
    private var removeResource: RemoveResource {
        .passkey(passkey)
    }
    
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading) {
                Text(passkey.name)
                    .font(.footnote.weight(.medium))
                
                Group {
                    Text("Created: " + dateFormatter.string(from: passkey.createdAt))
                    if let lastUsedAt = passkey.lastUsedAt {
                        Text("Last used: " + dateFormatter.string(from: lastUsedAt))
                    }
                }
                .foregroundStyle(clerkTheme.colors.textSecondary)
                .font(.footnote)
            }
            .confirmationDialog(
                Text(removeResource.messageLine1),
                isPresented: $confirmationSheetIsPresented,
                titleVisibility: .visible
            ) {
                AsyncButton(role: .destructive) {
                    do {
                        try await removeResource.deleteAction()
                    } catch {
                        errorWrapper = ErrorWrapper(error: error)
                    }
                } label: {
                    Text(removeResource.title)
                }
            } message: {
                Text(removeResource.messageLine2)
            }
            
            Spacer()
            
            Menu {
                AsyncButton {
                    renameIsPresented = true
                } label: {
                    Text("Rename")
                }
                
                AsyncButton(role: .destructive) {
                    confirmationSheetIsPresented = true
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
