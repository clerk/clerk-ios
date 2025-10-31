//
//  UserProfileExternalAccountRow.swift
//  Clerk
//
//  Created by Mike Pitre on 6/10/25.
//

#if os(iOS)

import ClerkKit
import NukeUI
import SwiftUI

struct UserProfileExternalAccountRow: View {
    @Environment(Clerk.self) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    @State private var removeResource: RemoveResource?
    @State private var isConfirmingRemoval = false
    @State private var isLoading = false
    @State private var error: Error?

    var user: User? {
        clerk.user
    }

    let externalAccount: ExternalAccount

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                WrappingHStack(alignment: .leading) {
                    HStack(spacing: 8) {
                        LazyImage(url: externalAccount.oauthProvider.iconImageUrl(darkMode: colorScheme == .dark)) { state in
                            if let image = state.image {
                                image
                                    .resizable()
                                    .scaledToFit()
                            } else {
                                #if DEBUG
                                Image(systemName: "globe")
                                    .resizable()
                                    .scaledToFit()
                                #endif
                            }
                        }
                        .frame(width: 20, height: 20)
                        .transition(.opacity.animation(.easeInOut(duration: 0.25)))

                        Text(externalAccount.oauthProvider.name)
                            .font(theme.fonts.subheadline)
                            .foregroundStyle(theme.colors.mutedForeground)
                            .frame(minHeight: 20)
                    }
                }

                if !externalAccount.emailAddress.isEmpty {
                    Text(externalAccount.emailAddress)
                        .font(theme.fonts.body)
                        .foregroundStyle(theme.colors.foreground)
                        .frame(minHeight: 22)
                }

                if let error = externalAccount.verification?.error {
                    ErrorText(error: error, alignment: .leading)
                        .font(theme.fonts.footnote)
                }
            }

            Spacer()

            Menu {
                if externalAccount.verification?.error != nil {
                    AsyncButton {
                        await reconnect()
                    } label: { _ in
                        Text("Reconnect", bundle: .module)
                    }
                    .onIsRunningChanged { isLoading = $0 }
                    .onDisappear { isLoading = false }
                }

                Button(role: .destructive) {
                    removeResource = .externalAccount(externalAccount)
                } label: {
                    Text("Remove connection", bundle: .module)
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
        .background(theme.colors.background)
        .overlayProgressView(isActive: isLoading)
        .overlay(alignment: .bottom) {
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(theme.colors.border)
        }
        .clerkErrorPresenting($error)
        .onChange(of: removeResource) {
            if $1 != nil { isConfirmingRemoval = true }
        }
        .confirmationDialog(
            removeResource?.messageLine1 ?? "",
            isPresented: $isConfirmingRemoval,
            titleVisibility: .visible,
            actions: {
                AsyncButton(role: .destructive) {
                    await removeResource(removeResource)
                } label: { isRunning in
                    Text(removeResource?.title ?? "", bundle: .module)
                }
                .onIsRunningChanged { isLoading = $0 }

                Button(role: .cancel) {
                    isConfirmingRemoval = false
                    removeResource = nil
                } label: {
                    Text("Cancel", bundle: .module)
                }
            }
        )
    }
}

extension UserProfileExternalAccountRow {

    private func reconnect() async {
        guard let user else { return }

        do {
            let account = try await user.createExternalAccount(provider: externalAccount.oauthProvider)
            try await account.reauthorize()
        } catch {
            self.error = error
            ClerkLogger.error("Failed to reconnect external account", error: error)
        }
    }

    private func removeResource(_ resource: RemoveResource?) async {
        defer { removeResource = nil }

        do {
            try await resource?.deleteAction()
        } catch {
            self.error = error
            ClerkLogger.error("Failed to remove external account resource", error: error)
        }
    }

}

#Preview {
    UserProfileExternalAccountRow(externalAccount: .mockVerified)
}

#endif
