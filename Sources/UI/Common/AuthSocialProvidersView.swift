//
//  AuthSocialProvidersView.swift
//
//
//  Created by Mike Pitre on 11/2/23.
//

#if os(iOS)

import SwiftUI
import Algorithms

struct AuthSocialProvidersView: View {
    @ObservedObject private var clerk = Clerk.shared
    @State private var errorWrapper: ErrorWrapper?
    @Environment(\.clerkTheme) private var clerkTheme
    @State private var stackWidth: CGFloat = .zero
    
    @State private var isSubmitting: Bool = false
    @Binding var captchaToken: String?
    @Binding var displayCaptcha: Bool
    @State private var selectedProvider: ExternalProvider?
    
    var onSuccess:((_ provider: ExternalProvider, _ wasTransfer: Bool) -> Void)?
    
    private var thirdPartyProviders: [ExternalProvider] {
        (clerk.environment?.userSettings.enabledThirdPartyProviders ?? []).sorted()
    }
    
    private var chunkedProviders: ChunksOfCountCollection<[ExternalProvider]> {
        thirdPartyProviders.chunks(ofCount: 4)
    }
        
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(chunkedProviders, id: \.self) { chunk in
                HStack(spacing: 8) {
                    ForEach(chunk) { provider in
                        AsyncButton {
                            await signIn(provider: provider, captchaToken: captchaToken)
                        } label: {
                            AuthProviderButton(provider: provider, style: thirdPartyProviders.count > 2 ? .compact : .regular)
                                .opacity(isSubmitting ? 0 : 1)
                                .overlay {
                                    if isSubmitting {
                                        ProgressView()
                                    }
                                }
                                .animation(.snappy, value: isSubmitting)
                                .frame(
                                    maxWidth: thirdPartyProviders.count <= 4 ? .infinity : max((stackWidth - 24) / 4, 0),
                                    minHeight: 30
                                )
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(clerkTheme.colors.textPrimary)
                        }
                        .buttonStyle(ClerkSecondaryButtonStyle())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .clerkErrorPresenting($errorWrapper)
        .readSize { stackSize in
            stackWidth = stackSize.width
        }
        .onChange(of: captchaToken) { token in
            if isSubmitting && token != nil, let selectedProvider {
                Task { await signIn(provider: selectedProvider, captchaToken: token) }
            }
        }
    }
    
    private func signIn(provider: ExternalProvider, captchaToken: String? = nil) async {
        KeyboardHelpers.dismissKeyboard()
        isSubmitting = true
        selectedProvider = provider
        
        do {
            if clerk.environment?.displayConfig.botProtectionIsEnabled == true && captchaToken == nil {
                displayCaptcha = true
            } else {
                let result = try await SignIn
                    .create(strategy: .externalProvider(provider))
                    .authenticateWithRedirect(captchaToken: captchaToken)
                isSubmitting = false
                onSuccess?(provider, result.wasTransfer)
            }
            
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            selectedProvider = nil
            isSubmitting = false
            displayCaptcha = false
            self.captchaToken = nil
            dump(error)
        }
    }
}

extension AuthSocialProvidersView {
    
    func onSuccess(perform action: @escaping (_ provider: ExternalProvider, _ wasTransfer: Bool) -> Void) -> Self {
        var copy = self
        copy.onSuccess = action
        return copy
    }
    
}

#Preview {
    AuthSocialProvidersView(captchaToken: .constant(nil), displayCaptcha: .constant(false))
        .padding()
}

#endif
