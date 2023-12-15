//
//  SignInForgotPasswordView.swift
//
//
//  Created by Mike Pitre on 12/15/23.
//

import SwiftUI
import Clerk
import NukeUI

struct SignInForgotPasswordView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.clerkTheme) private var clerkTheme
    
    private var thirdPartyProviders: [OAuthProvider] {
        clerk.environment.userSettings.enabledThirdPartyProviders.sorted()
    }
    
    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: .zero) {
                    Image(systemName: "circle.square.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .padding(.bottom, 24)
                        .foregroundStyle(clerkTheme.colors.gray700)
                    
                    Text("Forgot password?")
                        .font(.body.weight(.bold))
                        .foregroundStyle(clerkTheme.colors.gray700)
                        .padding(.bottom, 32)
                    
                    Button {
                        // reset password
                    } label: {
                        Text("Reset password")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClerkPrimaryButtonStyle())
                    
                    TextDivider(text: "Or, sign in with other method")
                        .padding(.vertical, 24)
                    
                    VStack(spacing: 8) {
                        ForEach(thirdPartyProviders) { provider in
                            AsyncButton {
                                //
                            } label: {
                                HStack {
                                    LazyImage(url: provider.iconImageUrl) { state in
                                        if let image = state.image {
                                            image.resizable().scaledToFit()
                                        } else {
                                            Color(.secondarySystemBackground)
                                        }
                                    }
                                    .frame(width: 16, height: 16)
                                    
                                    Text("Continue with \(provider.data.name)")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ClerkSecondaryButtonStyle())
                        }
                    }
                    .padding(.bottom, 18)
                    
                    Button {
                        clerkUIState.presentedAuthStep = .signInFactorOne
                    } label: {
                        Text("Back to previous method")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(clerkTheme.colors.gray700)
                            .frame(minHeight: ClerkStyleConstants.textMinHeight)
                    }
                }
                .frame(maxWidth: 320)
                .padding(32)
            }
            
            SecuredByClerkView()
                .padding()
        }
    }
}

#Preview {
    SignInForgotPasswordView()
        .environmentObject(Clerk.mock)
}
