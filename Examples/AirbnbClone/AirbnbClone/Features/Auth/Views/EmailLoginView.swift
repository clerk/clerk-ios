//
//  EmailLoginView.swift
//  AirbnbClone
//
//  Created by Mike Pitre on 12/15/25.
//

import ClerkKit
import SwiftUI

struct EmailLoginView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(Router.self) private var router
  @Environment(\.otpLoginMode) private var otpLoginMode

  @State private var email = ""
  @State private var showValidationError = false
  @State private var isLoading = false
  @State private var errorMessage: String?
  @FocusState private var isEmailFieldFocused: Bool

  private var isValidEmail: Bool {
    let emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    return email.wholeMatch(of: emailRegex) != nil
  }

  var body: some View {
    VStack(spacing: 0) {
      EmailInputField(
        email: $email,
        isFocused: $isEmailFieldFocused
      )

      ValidationError(message: "Please enter a valid email address", isVisible: showValidationError)
        .padding(.top, 8)

      ErrorMessage(message: errorMessage)
        .padding(.top, 8)

      ContinueButton(isLoading: isLoading) {
        dismissKeyboard()
        if isValidEmail {
          showValidationError = false
          submitEmail()
        } else {
          showValidationError = true
        }
      }
      .padding(.top, (showValidationError || errorMessage != nil) ? 10 : 16)
    }
    .animation(.default, value: showValidationError)
    .animation(.default, value: errorMessage)
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") {
          isEmailFieldFocused = false
        }
      }
    }
    .onChange(of: email) {
      if showValidationError, isValidEmail {
        showValidationError = false
      }
    }
  }

  private func submitEmail() {
    Task {
      errorMessage = nil
      isLoading = true
      defer { isLoading = false }

      do {
        // Try sign up first
        try await clerk.auth.signUp(emailAddress: email)
        router.authPath.append(
          AuthDestination.finishSigningUp(
            identifierValue: email,
            loginMode: .signUp(method: .email)
          )
        )
      } catch {
        // If sign up fails, try sign in
        do {
          try await clerk.auth.signInWithEmailCode(emailAddress: email)
          otpLoginMode.wrappedValue = .signIn(method: .email)
          router.showOTPVerification = true
        } catch {
          errorMessage = error.localizedDescription
        }
      }
    }
  }
}

// MARK: - EmailInputField

private struct EmailInputField: View {
  @Binding var email: String
  var isFocused: FocusState<Bool>.Binding

  private var borderColor: Color {
    isFocused.wrappedValue ? Color(uiColor: .label) : Color(uiColor: .separator)
  }

  private var borderWidth: CGFloat {
    isFocused.wrappedValue ? 2 : 1
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text("Email")
        .font(.system(size: 12))
        .foregroundStyle(.secondary)

      TextField("", text: $email)
        .font(.system(size: 16))
        .keyboardType(.emailAddress)
        .textContentType(.emailAddress)
        .autocapitalization(.none)
        .autocorrectionDisabled()
        .focused(isFocused)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(
      RoundedRectangle(cornerRadius: 10)
        .strokeBorder(borderColor, lineWidth: borderWidth)
    )
    .animation(.easeInOut(duration: 0.2), value: isFocused.wrappedValue)
  }
}

// MARK: - Preview

#Preview {
  EmailLoginView()
    .padding()
    .environment(Clerk.preview())
    .environment(Router())
}
