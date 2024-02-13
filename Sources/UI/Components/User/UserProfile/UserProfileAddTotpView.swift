//
//  UserProfileAddTotpView.swift
//
//
//  Created by Mike Pitre on 2/13/24.
//

import SwiftUI

struct UserProfileAddTotpView: View {
    @EnvironmentObject private var clerk: Clerk
    @Environment(\.dismiss) private var dismiss
    @State private var errorWrapper: ErrorWrapper?
    
    private var user: User? {
        clerk.user
    }
    
    @State private var totp: TOTPResource?
    
    var body: some View {
        ScrollView {
            if let totp {
                VStack(alignment: .leading, spacing: .zero) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add authenticator application")
                            .font(.footnote.weight(.bold))
                            .frame(minHeight: 18)
                        Text("Set up a new sign-in method in your authenticator and enter the Key provided below.\n\nMake sure Time-based or One-time passwords is enabled, then finish linking your account.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 16)
                    
                    HStack {
                        Text(totp.secret)
                            .font(.footnote)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            // copy secret
                        } label: {
                            Image(systemName: "clipboard.fill")
                                .imageScale(.small)
                        }
                        .tint(.primary)
                    }
                    .padding(8)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(.quaternary, lineWidth: 1)
                    }
                    .padding(.bottom, 16)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Alternatively, if your authenticator supports TOTP URIs, you can also copy the full URI.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text(verbatim: totp.uri)
                                .font(.footnote)
                                .lineLimit(1)
                            Spacer()
                            Button {
                                // copy uri
                            } label: {
                                Image(systemName: "clipboard.fill")
                                    .imageScale(.small)
                            }
                            .tint(.primary)
                        }
                        .padding(8)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(.quaternary, lineWidth: 1)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .safeAreaInset(edge: .bottom) {
            if let totp {
                AsyncButton {
                    // go to verify
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .clerkStandardButtonPadding()
                }
                .buttonStyle(ClerkPrimaryButtonStyle())
            }
        }
        .padding()
        .padding(.top, 30)
        .dismissButtonOverlay()
        .clerkErrorPresenting($errorWrapper)
        .overlay {
            if totp == nil {
                ProgressView()
            }
        }
        .task {
            await createTOTP()
        }
    }
    
    private func createTOTP() async {
        do {
            totp = try await user?.createTOTP()
        } catch {
            errorWrapper = ErrorWrapper(error: error)
        }
    }
}

#Preview {
    UserProfileAddTotpView()
        .environmentObject(Clerk.shared)
}
