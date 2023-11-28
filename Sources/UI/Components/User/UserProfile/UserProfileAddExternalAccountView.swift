//
//  UserProfileAddExternalAccountView.swift
//
//
//  Created by Mike Pitre on 11/9/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk
import Factory

struct UserProfileAddExternalAccountView: View {
    @EnvironmentObject private var clerk: Clerk
    @Environment(\.clerkTheme) private var clerkTheme
    @Environment(\.dismiss) private var dismiss
    
    private var user: User? {
        clerk.client.lastActiveSession?.user
    }
    
    private func create(provider: OAuthProvider) async {
        do {
            guard let user else { throw ClerkClientError(message: "Unable to find the current user.") }
            let newExternalAccount = try await user.addExternalAccount(provider)
            try await newExternalAccount.startOAuth()
            dismiss()
        } catch {
            dump(error)
        }
    }
        
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Add connected account")
                    .font(.title2.weight(.bold))
                
                Text("Select a provider to connect your account.")
                    .font(.footnote)
                
                VStack {
                    ForEach(user?.unconnectedProviders ?? []) { provider in
                        AsyncButton {
                            await create(provider: provider)
                        } label: {
                            AuthProviderButton(
                                provider: provider,
                                label: "Connect \(provider.data.name) account"
                            )
                            .font(.footnote)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Text("CANCEL")
                            .foregroundStyle(clerkTheme.colors.primary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .font(.caption.weight(.bold))
                    }
                }
            }
            .animation(.snappy, value: user)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(30)
        }
        .task {
            try? await clerk.environment.get()
        }
    }
}

#Preview {
    _ = Container.shared.clerk.register { .mock }
    return UserProfileAddExternalAccountView()
        .environmentObject(Clerk.mock)
}

#endif
