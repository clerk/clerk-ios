//
//  UserProfileAddExternalAccountView.swift
//
//
//  Created by Mike Pitre on 11/9/23.
//

#if canImport(UIKit)

import SwiftUI

struct UserProfileAddExternalAccountView: View {
    @EnvironmentObject private var clerk: Clerk
    @Environment(\.clerkTheme) private var clerkTheme
    @Environment(\.dismiss) private var dismiss
    @State private var errorWrapper: ErrorWrapper?
    
    private var user: User? {
        clerk.client.lastActiveSession?.user
    }
    
    private func create(provider: ExternalProvider) async {
        do {
            guard let user else { throw ClerkClientError(message: "Unable to find the current user.") }
            let newExternalAccount = try await user.createExternalAccount(provider)
            try await newExternalAccount.startExternalAuth()
            dismiss()
        } catch {
            errorWrapper = ErrorWrapper(error: error)
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
                            .clerkStandardButtonPadding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(ClerkSecondaryButtonStyle())
                    }
                }
                
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .clerkStandardButtonPadding()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClerkSecondaryButtonStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .padding(.top, 30)
        }
        .clerkErrorPresenting($errorWrapper)
        .dismissButtonOverlay()
        .task {
            try? await clerk.environment.get()
        }
    }
}

#Preview {
    return UserProfileAddExternalAccountView()
        .environmentObject(Clerk.shared)
}

#endif
