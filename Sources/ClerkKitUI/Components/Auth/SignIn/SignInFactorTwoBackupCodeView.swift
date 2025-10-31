//
//  SignInFactorTwoBackupCodeView.swift
//  Clerk
//
//  Created by Mike Pitre on 5/14/25.
//

#if os(iOS)

import SwiftUI

struct SignInFactorTwoBackupCodeView: View {
    @Environment(Clerk.self) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(AuthState.self) private var authState

    @FocusState private var isFocused: Bool
    @State private var fieldError: Error?

    var signIn: SignIn? {
        clerk.client?.signIn
    }

    let factor: Factor

    var body: some View {
        @Bindable var authState = authState

        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    HeaderView(style: .title, text: "Enter a backup code")
                    HeaderView(style: .subtitle, text: "Your backup code is the one you got when setting up two-step authentication.")
                }
                .padding(.bottom, 32)

                VStack(spacing: 24) {

                    VStack(spacing: 8) {
                        ClerkTextField(
                            "Backup code",
                            text: $authState.signInBackupCode,
                            fieldState: fieldError != nil ? .error : .default
                        )
                        .textInputAutocapitalization(.never)
                        .focused($isFocused)
                        .onFirstAppear {
                            isFocused = true
                        }

                        if let fieldError {
                            ErrorText(error: fieldError, alignment: .leading)
                                .font(theme.fonts.subheadline)
                                .transition(.blurReplace.animation(.default.speed(2)))
                                .id(fieldError.localizedDescription)
                        }
                    }

                    AsyncButton {
                        await submit()
                    } label: { isRunning in
                        HStack(spacing: 4) {
                            Text("Continue", bundle: .module)
                            Image("icon-triangle-right", bundle: .module)
                                .foregroundStyle(theme.colors.primaryForeground)
                                .opacity(0.6)
                        }
                        .frame(maxWidth: .infinity)
                        .overlayProgressView(isActive: isRunning) {
                            SpinnerView(color: theme.colors.primaryForeground)
                        }
                    }
                    .buttonStyle(.primary())
                    .disabled(authState.signInBackupCode.isEmpty)
                    .simultaneousGesture(TapGesture())
                }
                .padding(.bottom, 16)

                Button {
                    authState.path.append(
                        AuthView.Destination.signInFactorTwoUseAnotherMethod(
                            currentFactor: factor
                        )
                    )
                } label: {
                    Text("Use another method", bundle: .module)
                        .frame(maxWidth: .infinity)
                }
                .padding(.bottom, 32)

                SecuredByClerkView()
            }
            .padding(16)
        }
        .background(theme.colors.background)
        .sensoryFeedback(.error, trigger: fieldError?.localizedDescription) {
            $1 != nil
        }
    }
}

extension SignInFactorTwoBackupCodeView {

    func submit() async {
        isFocused = false

        do {
            guard var signIn else {
                authState.path = []
                return
            }

            signIn = try await signIn.attemptSecondFactor(
                strategy: .backupCode(code: authState.signInBackupCode)
            )

            fieldError = nil
            authState.setToStepForStatus(signIn: signIn)
        } catch {
            self.fieldError = error
        }
    }

}

#Preview {
    SignInFactorTwoBackupCodeView(factor: .mockBackupCode)
        .environment(\.clerkTheme, .clerk)
}

#endif
