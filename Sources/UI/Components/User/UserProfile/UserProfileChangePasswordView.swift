//
//  UserProfileChangePasswordView.swift
//
//
//  Created by Mike Pitre on 11/27/23.
//

#if os(iOS)

import SwiftUI

struct UserProfileChangePasswordView: View {
    @ObservedObject private var clerk = Clerk.shared
    @Environment(\.clerkTheme) private var clerkTheme
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var signOutOfOtherDevices = true
    @State private var errorWrapper: ErrorWrapper?
    @FocusState private var focusedField: Field?
    
    enum Field {
        case currentPassword, newPassword, confirmPassword
    }
    
    private var user: User? {
        clerk.client?.lastActiveSession?.user
    }
    
    private var continueDisabled: Bool {
        currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty ||
        (newPassword != confirmPassword)
    }
    
    private func updatePassword() async {
        do {
            try await user?.updatePassword(.init(
                newPassword: newPassword,
                currentPassword: currentPassword,
                signOutOfOtherSessions: signOutOfOtherDevices
            ))
            
            dismiss()
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .zero) {
                Text("Change password")
                    .font(.title2.weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 30)
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("Current password").font(.footnote.weight(.medium))
                        CustomTextField(text: $currentPassword, isSecureField: true)
                            .textContentType(.password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .currentPassword)
                            .task {
                                focusedField = .currentPassword
                            }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("New password").font(.footnote.weight(.medium))
                        CustomTextField(text: $newPassword, isSecureField: true)
                            .textContentType(.newPassword)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .newPassword)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Confirm password").font(.footnote.weight(.medium))
                        CustomTextField(text: $confirmPassword, isSecureField: true)
                            .textContentType(.newPassword)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .confirmPassword)
                    }
                    
                    HStack {
                        Toggle(isOn: $signOutOfOtherDevices, label: { EmptyView() })
                            .labelsHidden()
                        
                        Text("Sign out of all other devices")
                            .font(.footnote.weight(.medium))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 30)
                
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .clerkStandardButtonPadding()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClerkSecondaryButtonStyle())
                    
                    AsyncButton {
                        await updatePassword()
                    } label: {
                        Text("Continue")
                            .clerkStandardButtonPadding()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClerkPrimaryButtonStyle())
                    .disabled(continueDisabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .padding(.top, 30)
        }
        .dismissButtonOverlay()
        .clerkErrorPresenting($errorWrapper)
    }
}

#Preview {
    UserProfileChangePasswordView()
}

#endif
