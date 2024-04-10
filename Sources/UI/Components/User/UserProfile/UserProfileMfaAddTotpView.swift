//
//  UserProfileAddTotpView.swift
//
//
//  Created by Mike Pitre on 2/13/24.
//

#if canImport(UIKit)

import SwiftUI

extension UserProfileMfaAddTotpView {
    enum Step: Hashable, Equatable {
        case loading
        case add(totp: TOTPResource)
        case verify
        case backupCodes(_ backupCodes: [String])
    }
}

struct UserProfileMfaAddTotpView: View {
    @ObservedObject private var clerk = Clerk.shared
    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .loading
    @State private var errorWrapper: ErrorWrapper?
    
    private var user: User? {
        clerk.user
    }
        
    var body: some View {
        ZStack {
            switch step {
            case .loading:
                ProgressView()
            case .add:
                AddTOTPView(step: $step)
            case .verify:
                VerifyTOTPView(step: $step)
            case .backupCodes(let codes):
                TOTPBackupCodesView(backupCodes: codes)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.95).combined(with: .opacity),
            removal: .opacity.animation(nil)
        ))
        .id(step)
        .animation(.snappy, value: step)
        .dismissButtonOverlay()
        .clerkErrorPresenting($errorWrapper)
        .task {
            await createTOTP()
        }
    }
    
    private func createTOTP() async {
        do {
            guard let user else { return }
            let totp = try await user.createTOTP()
            step = .add(totp: totp)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
        }
    }
}

#Preview {
    UserProfileMfaAddTotpView()
}

private struct AddTOTPView: View {
    @Binding var step: UserProfileMfaAddTotpView.Step
    
    var body: some View {
        ScrollView {
            if case .add(let totp) = step {
                VStack(alignment: .leading, spacing: .zero) {
                    VStack(alignment: .leading) {
                        Text("Add authenticator application")
                            .font(.title2.weight(.bold))
                        
                        Text("Set up a new sign-in method in your authenticator and enter the Key provided below.\n\nMake sure Time-based or One-time passwords is enabled, then finish linking your account.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 16)
                    
                    HStack {
                        Text(totp.secret ?? "")
                            .font(.footnote)
                            .lineLimit(1)
                        Spacer()
                        #if !os(tvOS)
                        Button {
                            UIPasteboard.general.string = totp.secret
                        } label: {
                            Image(systemName: "clipboard.fill")
                                .imageScale(.small)
                        }
                        .tint(.primary)
                        #endif
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
                            Text(verbatim: totp.uri ?? "")
                                .font(.footnote)
                                .lineLimit(1)
                            Spacer()
                            #if !os(tvOS)
                            Button {
                                UIPasteboard.general.string = totp.uri
                            } label: {
                                Image(systemName: "clipboard.fill")
                                    .imageScale(.small)
                            }
                            .tint(.primary)
                            #endif
                        }
                        .padding(8)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(.quaternary, lineWidth: 1)
                        }
                    }
                }
                .padding()
                .padding(.top, 30)
            }
        }
        .safeAreaInset(edge: .bottom) {
            AsyncButton {
                step = .verify
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .clerkStandardButtonPadding()
            }
            .buttonStyle(ClerkPrimaryButtonStyle())
            .padding()
        }
    }
}

#Preview {
    AddTOTPView(step: .constant(.add(totp: TOTPResource(
        object: "totp",
        id: UUID().uuidString,
        secret: UUID().uuidString,
        uri: UUID().uuidString,
        verified: false,
        backupCodes: nil,
        createdAt: .now,
        updatedAt: .now
    ))))
}

private struct VerifyTOTPView: View {
    @ObservedObject private var clerk = Clerk.shared
    @State private var code = ""
    @State private var errorWrapper: ErrorWrapper?
    @Binding var step: UserProfileMfaAddTotpView.Step
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: .zero) {
                VerificationCodeView(
                    code: $code,
                    title: "Verification code",
                    subtitle: "Enter verification code generated by your authenticator"
                )
                .onCodeEntry {
                    await attemptVerification()
                }
                .onContinueAction {
                    //
                }
                
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .clerkStandardButtonPadding()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ClerkSecondaryButtonStyle())
            }
            .padding()
            .padding(.top, 30)
        }
        .clerkErrorPresenting($errorWrapper)
    }
    
    private func attemptVerification() async {
        do {
            guard let user = clerk.user else { return }
            let totp = try await user.verifyTOTP(code: code)
            if let backupCodes = totp.backupCodes {
                step = .backupCodes(backupCodes)
            } else {
                dismiss()
            }
        } catch {
            self.errorWrapper = ErrorWrapper(error: error)
            code = ""
            dump(error)
        }
    }
}

#Preview {
    VerifyTOTPView(step: .constant(.verify))
}

private struct TOTPBackupCodesView: View {
    @Environment(\.clerkTheme) private var clerkTheme
    @Environment(\.dismiss) private var dismiss
    
    let backupCodes: [String]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Add authenticator application")
                        .foregroundStyle(clerkTheme.colors.textPrimary)
                        .font(.footnote.weight(.medium))
                    Text("Two-step verification is now enabled. When signing in, you will need to enter a verification code from this authenticator as an additional step.")
                        .foregroundStyle(clerkTheme.colors.textTertiary)
                        .font(.footnote)
                }
                
                UserProfileMfaBackupCodeListView(backupCodes: backupCodes)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .padding(.top, 30)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                dismiss()
            } label: {
                Text("Finish")
                    .frame(maxWidth: .infinity)
                    .clerkStandardButtonPadding()
            }
            .buttonStyle(ClerkPrimaryButtonStyle())
            .padding()
        }
    }
}

#Preview {
    TOTPBackupCodesView(backupCodes: [
        "bfvbhsa0",
        "hb1eds8o",
        "oy3t6xfg",
        "ubatpup3",
        "y9m08ppi",
        "k1sk99it",
        "ny6okyz3",
        "dg8bwbji",
        "g2eh9622",
        "flwmkdcp"
      ])
}

#endif
