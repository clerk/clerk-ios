//
//  UserProfileExternalAccountSection.swift
//
//
//  Created by Mike Pitre on 11/3/23.
//

#if os(iOS)

import SwiftUI
import NukeUI
import AuthenticationServices

struct UserProfileExternalAccountSection: View {
    @ObservedObject private var clerk = Clerk.shared
    @Environment(\.clerkTheme) private var clerkTheme
    @State private var addExternalAccountIsPresented = false
    @Namespace private var namespace
    
    private var user: User? {
        clerk.user
    }
    
    private var externalAccounts: [ExternalAccount] {
        (user?.externalAccounts ?? []).sorted()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connected accounts")
                .font(.footnote.weight(.medium))
                .frame(minHeight: 32)
            
            VStack(alignment: .leading, spacing: 16) {
                ForEach(externalAccounts) { externalAccount in
                    ExternalAccountRow(
                        user: user,
                        externalAccount: externalAccount,
                        namespace: namespace
                    )
                }
                
                if let user, !user.unconnectedProviders.isEmpty {
                    Button(action: {
                        addExternalAccountIsPresented = true
                    }, label: {
                        Text("+ Connect account")
                            .font(.caption.weight(.medium))
                            .tint(clerkTheme.colors.textPrimary)
                            .frame(minHeight: 32)
                    })
                }
            }
            .padding(.leading, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.snappy, value: user)
        .sheet(isPresented: $addExternalAccountIsPresented) {
            UserProfileAddExternalAccountView()
        }
    }
    
    private struct ExternalAccountRow: View {
        let user: User?
        let externalAccount: ExternalAccount
        let namespace: Namespace.ID
        @State private var confirmationSheetIsPresented = false
        @State private var errorWrapper: ErrorWrapper?
        @Environment(\.clerkTheme) private var clerkTheme
        
        private var removeResource: RemoveResource { .externalAccount(externalAccount) }
        
        var body: some View {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    if let provider = externalAccount.externalProvider {
                        AuthProviderIcon(provider: provider)
                            .frame(width: 16, height: 16)
                    }
                    
                    if let providerName = externalAccount.externalProvider?.info.name {
                        Text(providerName)
                            .font(.footnote)
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
                    }
                    
                    if !externalAccount.displayName.isEmpty {
                        Group {
                            Text("•")
                            Text(externalAccount.displayName)
                        }
                        .foregroundStyle(clerkTheme.colors.textSecondary)
                        .font(.footnote)
                    }
                                    
                    if externalAccount.verification?.status != .verified {
                        CapsuleTag(text: "Requires action", style: .warning)
                    }
                    
                    Spacer()
                    
                    Menu {
                        if externalAccount.verification?.error != nil || externalAccount.verification?.status != .verified {
                            retryConnectionButton
                        }
                        
                        Button("Remove connected account", role: .destructive) {
                            confirmationSheetIsPresented = true
                        }
                    } label: {
                        MoreActionsView()
                    }
                    .tint(clerkTheme.colors.textPrimary)
                }
                if let verificationError = externalAccount.verification?.error {
                    Text(verificationError.localizedDescription)
                        .font(.footnote)
                        .foregroundStyle(clerkTheme.colors.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 24)
                }
            }
            .clerkErrorPresenting($errorWrapper)
        }
        
        @ViewBuilder
        private var retryConnectionButton: some View {
            if let provider = externalAccount.externalProvider {
                AsyncButton {
                    await retryConnection(provider)
                } label: {
                    Text("Retry connection")
                }
            }
        }
        
        private func retryConnection(_ provider: ExternalProvider) async {
            do {
                if provider == .apple {
                    try await user?.linkAppleAccount()
                } else {
                    let externalAccount = try await user?.createExternalAccount(provider)
                    try await externalAccount?.reauthorize()
                }
            } catch {
                if case ASAuthorizationError.canceled = error { return }
                errorWrapper = ErrorWrapper(error: error)
                dump(error)
            }
        }
    }
}

#Preview {
    UserProfileExternalAccountSection()
        .padding()
}

#endif
