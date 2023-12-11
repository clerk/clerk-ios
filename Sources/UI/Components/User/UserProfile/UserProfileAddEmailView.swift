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
    public enum Step: Hashable, Identifiable {
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
            subtitle: "Enter the verification code sent to \(emailAddress?.emailAddress ?? "the email address provided.")"
        )
        .onCodeEntry {
            await attempt()
        }
        .onResend {
            await prepare()
        }
        .task {
           await prepare()
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Add email address")
                    .font(.title2.weight(.bold))
                
                content
                    .animation(.snappy, value: step)
                
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
                        AsyncButton {
                            await create()
                            guard let emailAddress else { return }
                            step = .code(emailAddress: emailAddress)
                        } label: {
                            Text("CONTINUE")
                                .foregroundStyle(clerkTheme.colors.primaryButtonTextColor)
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    clerkTheme.colors.primary,
                                    in: .rect(cornerRadius: 6, style: .continuous)
                                )
                        }
                    }
                }
                .animation(.snappy, value: step)
            }
            .padding(30)
        }
        .dismissButtonOverlay()
        .clerkErrorPresenting($errorWrapper)
    }
    
    private func create() async {
        do {
            guard let user else { throw ClerkClientError(message: "Unable to find the current user.") }
            self.emailAddress = try await user.addEmailAddress(email)
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
            dump(error)
        }
    }
}

#Preview {
    UserProfileAddEmailView()
        .environmentObject(Clerk.mock)
}

#endif
