//
//  SignUpCollectFieldView.swift
//  Clerk
//
//  Created by Mike Pitre on 6/20/25.
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SignUpCollectFieldView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthState.self) private var authState

  @State private var error: Error?
  @State private var usernameForPasswordKeeper = ""

  @FocusState private var isFocused: Bool

  var signUp: SignUp? {
    clerk.client?.signUp
  }

  enum Field: String {
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
        text: $authState.signUpEmailAddress
      )
      .textContentType(.emailAddress)
      .keyboardType(.emailAddress)
    case .phoneNumber:
      ClerkPhoneNumberField(
        "Enter your phone number",
        text: $authState.signUpPhoneNumber
      )
    case .password:
      ClerkTextField(
        "Choose your password",
        text: $authState.signUpPassword,
        isSecure: true
      )
      .textContentType(.newPassword)
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
        text: $authState.signUpUsername
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

  var fieldIsOptional: Bool {
    signUp?.fieldIsRequired(field: field.rawValue) == false
  }

  let field: Field

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
            .textInputAutocapitalization(.never)
            .focused($isFocused)
            .onAppear {
              isFocused = true
            }

          AsyncButton {
            await updateSignUp()
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
          .disabled(continueIsDisabled)
          .simultaneousGesture(TapGesture())

          if fieldIsOptional, let signUp {
            Button {
              authState.setToStepForStatus(signUp: signUp)
            } label: {
              Text("Skip", bundle: .module)
            }
            .buttonStyle(
              .primary(
                config: .init(emphasis: .none, size: .small)
              )
            )
          }
        }

        SecuredByClerkView()
      }
      .padding(16)
    }
    .scrollDismissesKeyboard(.interactively)
    .clerkErrorPresenting($error)
    .background(theme.colors.background)
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text("Sign up", bundle: .module)
          .font(theme.fonts.headline)
          .foregroundStyle(theme.colors.foreground)
      }
    }
    .navigationBarTitleDisplayMode(.inline)
  }
}

extension SignUpCollectFieldView {
  func updateSignUp() async {
    guard var signUp else { return }

    do {
      switch field {
      case .emailAddress:
        signUp = try await signUp.update(params: .init(emailAddress: authState.signUpEmailAddress))
      case .phoneNumber:
        signUp = try await signUp.update(params: .init(phoneNumber: authState.signUpPhoneNumber))
      case .password:
        signUp = try await signUp.update(params: .init(password: authState.signUpPassword))
      case .username:
        signUp = try await signUp.update(params: .init(username: authState.signUpUsername))
      }

      authState.setToStepForStatus(signUp: signUp)
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
