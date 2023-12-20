//
//  UserProfileChangePasswordView.swift
//
//
//  Created by Mike Pitre on 11/27/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct UserProfileChangePasswordView: View {
    @EnvironmentObject private var clerk: Clerk
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
        clerk.client.lastActiveSession?.user
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
            VStack(alignment: .leading, spacing: 20) {
                Text("Change password")
                    .font(.title2.weight(.bold))
                
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
                    Toggle(isOn: $signOutOfOtherDevices) {
                        Text("Sign out of all other devices")
                            .font(.footnote.weight(.medium))
                    }
                    .labelsHidden()
                    .tint(clerkTheme.colors.primary)
                    
                    Text("Sign out of all other devices")
                        .font(.footnote.weight(.medium))
                }
                
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClerkSecondaryButtonStyle())
                    
                    AsyncButton {
                        await updatePassword()
                    } label: {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClerkPrimaryButtonStyle())
                    .disabled(continueDisabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .padding(.vertical)
        }
        .dismissButtonOverlay()
        .clerkErrorPresenting($errorWrapper)
    }
}

#Preview {
    UserProfileChangePasswordView()
}

#endif
