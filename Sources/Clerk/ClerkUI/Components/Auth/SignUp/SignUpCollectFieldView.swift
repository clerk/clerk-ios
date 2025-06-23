//
//  SignUpCollectFieldView.swift
//  Clerk
//
//  Created by Mike Pitre on 6/20/25.
//

#if os(iOS)

  import SwiftUI

  struct SignUpCollectFieldView: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.authState) private var authState

    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var username = ""
    @State private var error: Error?
    @State private var usernameForPasswordKeeper = ""
    
    @FocusState private var isFocused: Bool

    var signUp: SignUp? {
      clerk.client?.signUp
    }

    enum Field: String {
      case emailAddress = "email_address"
      case phoneNumber = "phone_number"
      case password = "password"
      case username = "username"
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
      switch field {
      case .emailAddress:
        ClerkTextField(
          "Enter your email",
          text: $email
        )
        .textContentType(.emailAddress)
        .keyboardType(.emailAddress)
      case .phoneNumber:
        ClerkPhoneNumberField(
          "Enter your phone number",
          text: $phone
        )
      case .password:
        ClerkTextField(
          "Choose your password",
          text: $password,
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
          text: $username,
        )
        .textContentType(.username)
      }
    }

    var continueIsDisabled: Bool {
      switch field {
      case .emailAddress:
        email.isEmptyTrimmed
      case .phoneNumber:
        phone.isEmptyTrimmed
      case .password:
        password.isEmptyTrimmed
      case .username:
        username.isEmptyTrimmed
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
                  .foregroundStyle(theme.colors.textOnPrimaryBackground)
                  .opacity(0.6)
              }
              .frame(maxWidth: .infinity)
              .overlayProgressView(isActive: isRunning) {
                SpinnerView(color: theme.colors.textOnPrimaryBackground)
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
      .background(theme.colors.background)
      .clerkErrorPresenting($error)
      .navigationBarBackButtonHidden()
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text("Sign up", bundle: .module)
            .font(theme.fonts.headline)
            .foregroundStyle(theme.colors.text)
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
          signUp = try await signUp.update(params: .init(emailAddress: email))
        case .phoneNumber:
          signUp = try await signUp.update(params: .init(phoneNumber: email))
        case .password:
          signUp = try await signUp.update(params: .init(password: password))
        case .username:
          signUp = try await signUp.update(params: .init(username: username))
        }
        
        authState.setToStepForStatus(signUp: signUp)
      } catch {
        self.error = error
      }
    }
    
  }

  #Preview {
    SignUpCollectFieldView(field: .password)
      .environment(\.clerkTheme, .clerk)
  }

#endif
