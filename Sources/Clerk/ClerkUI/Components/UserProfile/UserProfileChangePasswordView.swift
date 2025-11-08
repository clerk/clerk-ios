//
//  UserProfileChangePasswordView.swift
//  Clerk
//
//  Created by Mike Pitre on 6/16/25.
//

#if os(iOS)

import SwiftUI

struct UserProfileChangePasswordView: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var path = NavigationPath()
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmNewPassword = ""
    @State private var signOutOfOtherSessions = false
    @State private var error: Error?

    @FocusState private var focusedField: Field?

    enum Field {
        case currentPassword, newPassword, confirmNewPassword
    }

    enum Destination {
        case updatePassword
    }

    var nextIsDisabled: Bool {
        currentPassword.isEmptyTrimmed
    }

    var saveIsDisabled: Bool {
        newPassword.isEmptyTrimmed || confirmNewPassword.isEmptyTrimmed || newPassword != confirmNewPassword
    }

    var user: User? { clerk.user }

    var isAddingPassword: Bool = false
    
    private var isDefaultTheme: Bool {
        theme.colors.primary == ClerkTheme.Colors.defaultPrimaryColor
    }

    var body: some View {
        NavigationStack(path: $path) {
            if isAddingPassword {
                updatePasswordView
            } else {
                currentPasswordView
                    .navigationDestination(for: Destination.self) {
                        switch $0 {
                        case .updatePassword:
                            updatePasswordView
                        }
                    }
            }
        }
        .presentationBackground(theme.colors.background)
        .background(theme.colors.background)
    }

    @ViewBuilder
    private var currentPasswordView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Enter your current password to set a new one.", bundle: .module)
                    .font(theme.fonts.subheadline)
                    .foregroundStyle(theme.colors.mutedForeground)
                    .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
                    .multilineTextAlignment(.leading)

                ClerkTextField("Current password", text: $currentPassword, isSecure: true)
                    .textContentType(.password)
                    .focused($focusedField, equals: .currentPassword)

                Button {
                    path.append(Destination.updatePassword)
                } label: {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary())
                .disabled(nextIsDisabled)
            }
            .padding(24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .preGlassSolidNavBar()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundStyle(theme.colors.primary)
            }

            ToolbarItem(placement: .principal) {
                Text("Update password", bundle: .module)
                    .font(theme.fonts.headline)
                    .foregroundStyle(theme.colors.foreground)
            }
        }
        .onAppear {
            focusedField = .currentPassword
        }
    }

    @ViewBuilder
    private var updatePasswordView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Group {
                    ClerkTextField("New password", text: $newPassword, isSecure: true)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .newPassword)
                        .hiddenTextField(text: .constant(user?.usernameForPasswordKeeper ?? ""), textContentType: .username)

                    ClerkTextField("Confirm password", text: $confirmNewPassword, isSecure: true)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .confirmNewPassword)
                }
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

                signOutOfOtherDevicesView

                AsyncButton {
                    await resetPassword()
                } label: { isRunning in
                    Text("Save")
                        .frame(maxWidth: .infinity)
                        .overlayProgressView(isActive: isRunning) {
                            SpinnerView(color: theme.colors.primaryForeground)
                        }
                }
                .buttonStyle(.primary())
                .disabled(saveIsDisabled)
            }
            .padding(24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .preGlassSolidNavBar()
        .clerkErrorPresenting(
            $error,
            action: { error in
                if let clerkApiError = error as? ClerkAPIError, clerkApiError.meta?["param_name"]?.stringValue == "current_password" {
                    return .init(text: "Go back") {
                        path = NavigationPath()
                    }
                }

                return nil
            }
        )
        .toolbar {
            if isAddingPassword {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(theme.colors.primary)
                }
            }

            ToolbarItem(placement: .principal) {
                Text(isAddingPassword ? "Add password" : "Update password", bundle: .module)
                    .font(theme.fonts.headline)
                    .foregroundStyle(theme.colors.foreground)
            }
        }
        .onFirstAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                focusedField = .newPassword
            }
        }
    }

    @ViewBuilder
    private var signOutOfOtherDevicesView: some View {
        VStack(spacing: 8) {
            Group {
                if isDefaultTheme {
                    Toggle("Sign out of all other devices", isOn: $signOutOfOtherSessions)
                        .font(theme.fonts.body)
                        .foregroundStyle(theme.colors.foreground)
                        .frame(minHeight: 22)
                } else {
                    Toggle("Sign out of all other devices", isOn: $signOutOfOtherSessions)
                        .font(theme.fonts.body)
                        .foregroundStyle(theme.colors.foreground)
                        .tint(theme.colors.primary)
                        .frame(minHeight: 22)
                }
            }

            Text("It is recommended to sign out of all other devices which may have used your old password.", bundle: .module)
                .font(theme.fonts.subheadline)
                .foregroundStyle(theme.colors.mutedForeground)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(theme.colors.muted, in: .rect(cornerRadius: theme.design.borderRadius))
    }
}

extension UserProfileChangePasswordView {

    func resetPassword() async {
        guard let user else { return }

        do {
            try await user.updatePassword(
                .init(
                    currentPassword: isAddingPassword ? nil : currentPassword,
                    newPassword: newPassword,
                    signOutOfOtherSessions: signOutOfOtherSessions
                )
            )
            dismiss()
        } catch {
            self.error = error
            ClerkLogger.error("Failed to reset password", error: error)
        }
    }

}

#Preview("Reset") {
    UserProfileChangePasswordView()
        .environment(\.clerk, .mock)
        .environment(\.clerkTheme, .clerk)
}

#Preview("Adding") {
    UserProfileChangePasswordView(isAddingPassword: true)
        .environment(\.clerk, .mock)
        .environment(\.clerkTheme, .clerk)
}

#endif
