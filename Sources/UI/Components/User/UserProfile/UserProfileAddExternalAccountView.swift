//
//  UserProfileAddExternalAccountView.swift
//
//
//  Created by Mike Pitre on 11/9/23.
//

#if os(iOS)

import SwiftUI
import AuthenticationServices

struct UserProfileAddExternalAccountView: View {
    @ObservedObject private var clerk = Clerk.shared
    @Environment(\.clerkTheme) private var clerkTheme
    @Environment(\.dismiss) private var dismiss
    @State private var errorWrapper: ErrorWrapper?
    
    private var user: User? {
        clerk.client?.lastActiveSession?.user
    }
    
    private func create(provider: ExternalProvider) async {
        do {
            guard let user else { throw ClerkClientError(message: "Unable to find the current user.") }
            if provider == .apple {
                try await user.linkAppleAccount()
            } else {
                let newExternalAccount = try await user.createExternalAccount(provider)
                try await newExternalAccount.reauthorize()
            }
        } catch {
            if case ASAuthorizationError.canceled = error { return }
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
                                label: "Connect \(provider.info.name) account"
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
        .onChange(of: user) { [user] newValue in
            if newValue?.unconnectedProviders.count ?? 0 < user?.unconnectedProviders.count ?? 0 {
                dismiss()
            }
        }
        .task {
            try? await clerk.getEnvironment()
        }
    }
}

#Preview {
    UserProfileAddExternalAccountView()
}

#endif
