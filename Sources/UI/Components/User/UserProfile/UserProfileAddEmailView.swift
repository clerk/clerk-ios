//
//  UserProfileAddEmailView.swift
//
//
//  Created by Mike Pitre on 11/6/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

extension UserProfileAddEmailView {
    enum Step {
        case add
        case code
    }
}

struct UserProfileAddEmailView: View {
    @EnvironmentObject private var clerk: Clerk
    @Environment(\.clerkTheme) private var clerkTheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var step: Step = .add
    @State private var email = ""
    @State private var code = ""
    
    // The email address object returned by the create call
    @State private var emailAddress: EmailAddress?
    
    @FocusState var isFocused: Bool
    
    private var user: User? {
        clerk.client.lastActiveSession?.user
    }
    
    private var preferredEmailVerificationStrategy: Strategy {
        clerk.environment.userSettings.preferredEmailVerificationStrategy ?? .emailCode
    }
    
    private var prepareStrategy: EmailAddress.PrepareStrategy {
        switch preferredEmailVerificationStrategy {
        case .emailCode:
            return .emailCode
        case .emailLink:
            return .emailLink
        default:
            return .emailCode
        }
    }
    
    private var instructionsString: String {
        switch preferredEmailVerificationStrategy {
        case .emailCode:
            return "An email containing a verification code will be sent to this email address."
        case .emailLink:
            return "An email containing a verification link will be sent to this email address."
        default:
            return ""
        }
    }
    
    @ViewBuilder
    private var content: some View {
        Group {
            switch step {
            case .add:
                addContent
            case .code:
                codeContent
            }
        }
        .transition(.offset(y: 50).combined(with: .opacity))
        .onChange(of: step) { _ in
            KeyboardHelpers.dismissKeyboard()
            FeedbackGenerator.success()
        }
    }
    
    @ViewBuilder
    private var addContent: some View {
        VStack(alignment: .leading) {
            Text("Email address")
                .font(.footnote.weight(.medium))
            CustomTextField(text: $email)
                .frame(height: 44)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .focused($isFocused)
                .task {
                    isFocused = true
                }
        }
        
        Text(instructionsString)
            .fixedSize(horizontal: false, vertical: true)
            .font(.footnote)
    }
    
    @ViewBuilder
    private var codeContent: some View {
        CodeFormView(
            code: $code,
            title: "Verification code",
            subtitle: "Enter the verification code sent to \(email)"
        )
        .onCodeEntry {
            await attempt()
        }
        .onResend {
            await prepare()
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Add email address")
                    .font(.title2.weight(.bold))
                
                content
                    .animation(.bouncy, value: step)
                
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
                    
                    if step == .add {
                        AsyncButton(options: [.disableButton, .showProgressView], action: {
                            await prepare()
                        }, label: {
                            Text("CONTINUE")
                                .foregroundStyle(clerkTheme.colors.primaryButtonTextColor)
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    clerkTheme.colors.primary,
                                    in: .rect(cornerRadius: 6, style: .continuous)
                                )
                        })
                    }
                }
                .animation(.bouncy, value: step)
            }
            .padding(30)
        }
    }
    
    private func prepare() async {
        do {
            guard let user else { throw ClerkClientError(message: "Unable to find the current user.") }
            self.emailAddress = try await user.addEmailAddress(email)
            try await self.emailAddress?.prepareVerification(strategy: prepareStrategy)
            self.step = .code
        } catch {
            dump(error)
        }
    }
    
    private func attempt() async {
        do {
            try await self.emailAddress?.attemptVerification(strategy: .emailCode(code: code))
            dismiss()
        } catch {
            dump(error)
        }
    }
}

#Preview {
    UserProfileAddEmailView()
        .environmentObject(Clerk.mock)
}

#endif
