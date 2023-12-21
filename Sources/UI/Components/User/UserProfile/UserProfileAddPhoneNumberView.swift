//
//  UserProfileAddPhoneNumberView.swift
//
//
//  Created by Mike Pitre on 11/8/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

extension UserProfileAddPhoneNumberView {
    public enum Step: Hashable, Identifiable {
        case add
        case code(phoneNumber: PhoneNumber)
        
        var id: Self { self }
    }
}

struct UserProfileAddPhoneNumberView: View {
    @EnvironmentObject private var clerk: Clerk
    @Environment(\.clerkTheme) private var clerkTheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var step: Step
    @State private var phone = ""
    @State private var code = ""
    @State private var errorWrapper: ErrorWrapper?
    
    // The email address object returned by the create call or
    // provided on init in the case of going straight to verification
    @State private var phoneNumber: PhoneNumber?
    
    @FocusState var isFocused: Bool
    
    private var user: User? {
        clerk.client.lastActiveSession?.user
    }
    
    init(initialStep: Step = .add) {
        self._step = State(initialValue: initialStep)
        if case .code(let phoneNumber) = initialStep {
            self._phoneNumber = State(initialValue: phoneNumber)
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
                Text("Phone number")
                    .font(.footnote.weight(.medium))
                PhoneNumberField(text: $phone)
                    .focused($isFocused)
                    .task {
                        isFocused = true
                    }
            }
            
            Text("A text message containing a verification code will be sent to this phone number.")
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .font(.footnote)
            
            Text("Message and data rates may apply.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            AsyncButton {
                await create()
                guard let phoneNumber else { return }
                step = .code(phoneNumber: phoneNumber)
            } label: {
                Text("Continue")
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
            title: "Check your phone",
            subtitle: "Enter the verification code sent to your phone",
            safeIdentifier: phoneNumber?.formatted(.international)
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
                    .animation(.snappy, value: step)
                
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ClerkSecondaryButtonStyle())
            }
            .padding()
            .padding(.vertical)
        }
        .transition(.asymmetric(
            insertion: .offset(y: 50).combined(with: .opacity),
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
            self.phoneNumber = try await user.addPhoneNumber(phone)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    private func prepare() async {
        do {
            try await self.phoneNumber?.prepareVerification(strategy: .phoneCode)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    private func attempt() async {
        do {
            try await self.phoneNumber?.attemptVerification(strategy: .phoneCode(code: code))
            dismiss()
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            code = ""
            dump(error)
        }
    }
}

#Preview {
    UserProfileAddPhoneNumberView()
        .environmentObject(Clerk.mock)
}

#endif
