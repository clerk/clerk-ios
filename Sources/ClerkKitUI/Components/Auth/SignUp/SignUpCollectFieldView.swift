//
//  SignUpCollectFieldView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct SignUpCollectFieldView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation
  @Environment(AuthState.self) private var authState

  @State private var error: Error?
  @State private var usernameForPasswordKeeper = ""

  @FocusState private var isFocused: Bool

  var signUp: SignUp? {
    clerk.auth.currentSignUp
  }

  let field: Field

  enum Field: String, Hashable {
    case emailAddress = "email_address"
    case phoneNumber = "phone_number"
    case password
    case username
  }

  var title: LocalizedStringKey {
    switch field {
    case .emailAddress:
      "Email address"
    case .phoneNumber:
      "Phone number"
    case .password:
      "Password"
    case .username:
      "Username"
    }
  }

  var subtitle: LocalizedStringKey {
    switch field {
    case .emailAddress:
      "Enter the email address you'd like to use."
    case .phoneNumber:
      "Enter the phone number you'd like to use."
    case .password:
      "Create a unique password."
    case .username:
      "Choose a username."
    }
  }

  @ViewBuilder
  var textField: some View {
    @Bindable var authState = authState

    switch field {
    case .emailAddress:
      ClerkTextField(
        "Enter your email",
        text: $authState.signUpEmailAddress,
        accessibilityIdentifier: ClerkAccessibilityIdentifiers.Auth.SignUp.emailAddress
      )
      .textContentType(.emailAddress)
      #if os(iOS)
        .keyboardType(.emailAddress)
      #endif
    case .phoneNumber:
      ClerkPhoneNumberField(
        "Enter your phone number",
        text: $authState.signUpPhoneNumber
      )
    case .password:
      ClerkTextField(
        "Choose your password",
        text: $authState.signUpPassword,
        isSecure: true,
        accessibilityIdentifier: ClerkAccessibilityIdentifiers.Auth.SignUp.password
      )
      .textContentType(ClerkE2EEnvironment.isEnabled ? nil : .newPassword)
      .hiddenTextField(
        text: $usernameForPasswordKeeper,
        textContentType: .username
      )
      .onAppear {
        usernameForPasswordKeeper = signUp?.username ?? signUp?.emailAddress ?? signUp?.phoneNumber ?? ""
      }
    case .username:
      ClerkTextField(
        "Choose your username",
        text: $authState.signUpUsername,
        accessibilityIdentifier: ClerkAccessibilityIdentifiers.Auth.SignUp.username
      )
      .textContentType(.username)
    }
  }

  var continueIsDisabled: Bool {
    switch field {
    case .emailAddress:
      authState.signUpEmailAddress.isEmptyTrimmed
    case .phoneNumber:
      authState.signUpPhoneNumber.isEmptyTrimmed
    case .password:
      authState.signUpPassword.isEmptyTrimmed
    case .username:
      authState.signUpUsername.isEmptyTrimmed
    }
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 32) {
        VStack(spacing: 8) {
          HeaderView(style: .title, text: title)
          HeaderView(style: .subtitle, text: subtitle)
        }

        VStack(spacing: 24) {
          textField
            .autocorrectionDisabled()
          #if os(iOS)
            .textInputAutocapitalization(.never)
          #endif
            .focused($isFocused)
            .onAppear {
              isFocused = true
            }

          AsyncButton {
            await updateSignUp()
          } label: { isRunning in
            ContinueButtonLabelView(isActive: isRunning)
          }
          .buttonStyle(.primary())
          .disabled(continueIsDisabled)
          .accessibilityIdentifier(ClerkAccessibilityIdentifiers.Auth.SignUp.continueButton)
          .simultaneousGesture(TapGesture())
        }

        SecuredByClerkView()
      }
      .padding(16)
    }
    #if os(iOS)
    .scrollDismissesKeyboard(.interactively)
    #endif
    .clerkErrorPresenting($error)
    .background(theme.colors.background)
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text("Sign up", bundle: .module)
          .font(theme.fonts.headline)
          .foregroundStyle(theme.colors.foreground)
      }
    }
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
  }
}

extension SignUpCollectFieldView {
  func updateSignUp() async {
    guard var signUp else { return }

    do {
      switch field {
      case .emailAddress:
        signUp = try await signUp.update(emailAddress: authState.signUpEmailAddress)
      case .phoneNumber:
        signUp = try await signUp.update(phoneNumber: authState.signUpPhoneNumber)
      case .password:
        signUp = try await signUp.update(password: authState.signUpPassword)
      case .username:
        signUp = try await signUp.update(username: authState.signUpUsername)
      }

      navigation.setToStepForStatus(signUp: signUp)
    } catch {
      self.error = error
      ClerkLogger.error("Failed to update sign up with field data", error: error)
    }
  }
}

#Preview {
  SignUpCollectFieldView(field: .password)
    .environment(\.clerkTheme, .clerk)
}

#endif
