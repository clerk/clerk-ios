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
        .transition(.offset(y: 50).combined(with: .opacity))
        .onChange(of: step) { _ in
            KeyboardHelpers.dismissKeyboard()
            FeedbackGenerator.success()
        }
    }
    
    @ViewBuilder
    private var addContent: some View {
        VStack(alignment: .leading) {
            Text("Phone number")
                .font(.footnote.weight(.medium))
            PhoneNumberField(text: $phone)
                .frame(height: 44)
                .focused($isFocused)
                .task {
                    isFocused = true
                }
        }
        
        Text("A text message containing a verification code will be sent to this phone number.")
            .fixedSize(horizontal: false, vertical: true)
            .font(.footnote)
        
        Text("Message and data rates may apply.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    
    @ViewBuilder
    private var codeContent: some View {
        CodeFormView(
            code: $code,
            title: "Verification code",
            subtitle: "Enter the verification code sent to \(phoneNumber?.formatted(.international) ?? "the phone number provided.")"
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
                Text("Add phone number")
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
                            guard let phoneNumber else { return }
                            step = .code(phoneNumber: phoneNumber)
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
            .dismissButtonOverlay()
        }
    }
    
    private func create() async {
        do {
            guard let user else { throw ClerkClientError(message: "Unable to find the current user.") }
            self.phoneNumber = try await user.addPhoneNumber(phone)
        } catch {
            dump(error)
        }
    }
    
    private func prepare() async {
        do {
            try await self.phoneNumber?.prepareVerification(strategy: .phoneCode)
        } catch {
            dump(error)
        }
    }
    
    private func attempt() async {
        do {
            try await self.phoneNumber?.attemptVerification(strategy: .phoneCode(code: code))
            dismiss()
        } catch {
            dump(error)
        }
    }
}

#Preview {
    UserProfileAddPhoneNumberView()
        .environmentObject(Clerk.mock)
}

#endif
