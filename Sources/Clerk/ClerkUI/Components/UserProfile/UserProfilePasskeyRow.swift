//
//  UserProfilePasskeyRow.swift
//  Clerk
//
//  Created by Mike Pitre on 5/29/25.
//

#if os(iOS)

import SwiftUI

struct UserProfilePasskeyRow: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme

    @State private var renameIsPresented = false
    @State private var isConfirmingRemoval = false
    @State private var removeResource: RemoveResource?
    @State private var isLoading = false
    @State private var error: Error?

    let passkey: Passkey

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: passkey.name)
                    .font(theme.fonts.body)
                    .foregroundStyle(theme.colors.foreground)
                    .frame(minHeight: 22)

                VStack(alignment: .leading, spacing: 0) {
                    Group {
                        Text("Created: \(passkey.createdAt.relativeNamedFormat)", bundle: .module)

                        if let lastUsedAt = passkey.lastUsedAt {
                            Text("Last used: \(lastUsedAt.relativeNamedFormat)", bundle: .module)
                        }
                    }
                    .font(theme.fonts.subheadline)
                    .foregroundStyle(theme.colors.mutedForeground)
                    .frame(minHeight: 20)
                }
            }

            Spacer(minLength: 0)

            Menu {
                Button {
                    renameIsPresented = true
                } label: {
                    Text("Rename", bundle: .module)
                }

                AsyncButton(role: .destructive) {
                    removeResource = .passkey(passkey)
                } label: { isRunning in
                    Text("Remove", bundle: .module)
                }

            } label: {
                Image("icon-three-dots-vertical", bundle: .module)
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(theme.colors.mutedForeground)
                    .frame(width: 20, height: 20)
            }
            .frame(width: 30, height: 30)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .overlayProgressView(isActive: isLoading)
        .overlay(alignment: .bottom) {
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(theme.colors.border)
        }
        .clerkErrorPresenting($error)
        .sheet(isPresented: $renameIsPresented) {
            UserProfilePasskeyRenameView(passkey: passkey)
        }
        .confirmationDialog(
            removeResource?.messageLine1 ?? "",
            isPresented: $isConfirmingRemoval,
            titleVisibility: .visible,
            actions: {
                AsyncButton(role: .destructive) {
                    await removeResource()
                } label: { isRunning in
                    Text(removeResource?.title ?? "", bundle: .module)
                }
                .onIsRunningChanged { isLoading = $0 }
            }
        )
        .onChange(of: removeResource) {
            if $1 != nil { isConfirmingRemoval = true }
        }
        .animation(.default, value: isLoading)
    }
}

extension UserProfilePasskeyRow {

    private func removeResource() async {
        defer { removeResource = nil }

        do {
            try await removeResource?.deleteAction()
        } catch {
            self.error = error
            ClerkLogger.error("Failed to remove passkey resource", error: error)
        }
    }

}

#Preview {
    UserProfilePasskeyRow(passkey: .mock)
        .environment(\.clerk, .mock)
        .environment(\.clerkTheme, .clerk)
}

#endif
