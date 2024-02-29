//
//  UserProfileAddEmailView.swift
//
//
//  Created by Mike Pitre on 11/6/23.
//

#if canImport(UIKit)

import SwiftUI

extension UserProfileAddEmailView {
    enum Step: Hashable, Identifiable {
        case add
        case code(emailAddress: EmailAddress)
        
        var id: Self { self }
    }
}

struct UserProfileAddEmailView: View {
    @EnvironmentObject private var clerk: Clerk
    @Environment(\.clerkTheme) private var clerkTheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var step: Step
    @State private var email = ""
    @State private var code = ""
    @State private var errorWrapper: ErrorWrapper?
    
    // The email address object returned by the create call or
    // provided on init in the case of going straight to verification
    @State private var emailAddress: EmailAddress?
    
    @FocusState var isFocused: Bool
    
    init(initialStep: Step = .add) {
        self._step = State(initialValue: initialStep)
        if case .code(let emailAddress) = initialStep {
            self._emailAddress = State(initialValue: emailAddress)
        }
    }
    
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
//        case .emailLink:
//            return .emailLink
        default:
            return .emailCode
        }
    }
    
    private var instructionsString: String {
        switch preferredEmailVerificationStrategy {
        case .emailCode:
            return "An email containing a verification code will be sent to this email address."
//        case .emailLink:
//            return "An email containing a verification link will be sent to this email address."
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
        .onChange(of: step) { _ in
            KeyboardHelpers.dismissKeyboard()
            FeedbackGenerator.success()
        }
    }
    
    @ViewBuilder
    private var addContent: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading) {
                Text("Email address")
                    .font(.footnote.weight(.medium))
                CustomTextField(text: $email)
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .font(.footnote)
            
            AsyncButton {
                await create()
                guard let emailAddress else { return }
                step = .code(emailAddress: emailAddress)
            } label: {
                Text("Continue")
                    .clerkStandardButtonPadding()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ClerkPrimaryButtonStyle())
            .padding(.bottom, 20)
        }
    }
    
    @ViewBuilder
    private var codeContent: some View {
        VerificationCodeView(
            code: $code,
            title: "Verification code",
            subtitle: "Enter the verification code sent to your email",
            safeIdentifier: emailAddress?.emailAddress
        )
        .onCodeEntry {
            await attempt()
        }
        .onResend {
            await prepare()
        }
        .onContinueAction {
            //
        }
        .task {
            await prepare()
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: .zero) {
                OrgLogoView()
                    .padding(.bottom, 24)
                
                content
                
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
            .padding(.vertical)
        }
        .transition(.asymmetric(
            insertion: .scale(scale: 0.95).combined(with: .opacity),
            removal: .opacity.animation(nil)
        ))
        .id(step)
        .animation(.snappy, value: step)
        .dismissButtonOverlay()
        .clerkErrorPresenting($errorWrapper)
    }
    
    private func create() async {
        do {
            guard let user else { throw ClerkClientError(message: "Unable to find the current user.") }
            self.emailAddress = try await user.createEmailAddress(email)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    private func prepare() async {
        do {
            try await self.emailAddress?.prepareVerification(strategy: prepareStrategy)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    private func attempt() async {
        do {
            try await self.emailAddress?.attemptVerification(strategy: .emailCode(code: code))
            dismiss()
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            code = ""
            dump(error)
        }
    }
}

#Preview {
    UserProfileAddEmailView()
        .environmentObject(Clerk.shared)
}

#endif
