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

  @Binding var showVerification: Bool
  @Binding var pendingVerification: PendingVerification?
  @Binding var isLoading: Bool
  @Binding var errorMessage: String?

  @State private var email = ""
  @State private var showValidationError = false
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

      EmailValidationError(isVisible: showValidationError)
        .padding(.top, 8)

      EmailContinueButton(isLoading: isLoading) {
        dismissKeyboard()
        if isValidEmail {
          showValidationError = false
          submitEmail()
        } else {
          showValidationError = true
        }
      }
      .padding(.top, showValidationError ? 10 : 16)
    }
    .animation(.default, value: showValidationError)
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
        let signIn = try await clerk.auth.signInWithEmailCode(emailAddress: email)
        pendingVerification = .signIn(signIn)
        showVerification = true
      } catch {
        if let apiError = error as? ClerkAPIError,
           ["form_identifier_not_found", "invitation_account_not_exists"].contains(apiError.code)
        {
          do {
            let signUp = try await clerk.auth.signUp(emailAddress: email)
            let prepared = try await signUp.sendEmailCode()
            pendingVerification = .signUp(prepared, .email)
            showVerification = true
          } catch {
            errorMessage = error.localizedDescription
          }
        } else {
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
  }
}

// MARK: - EmailValidationError

private struct EmailValidationError: View {
  let isVisible: Bool

  var body: some View {
    if isVisible {
      HStack(spacing: 6) {
        Image(systemName: "exclamationmark.circle.fill")
          .font(.system(size: 14))
        Text("Please enter a valid email address")
          .font(.system(size: 14))
      }
      .foregroundStyle(Color(red: 0.76, green: 0.15, blue: 0.18))
      .frame(maxWidth: .infinity, alignment: .leading)
      .transition(.opacity)
    }
  }
}

// MARK: - EmailContinueButton

private struct EmailContinueButton: View {
  let isLoading: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text("Continue")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.white)
        .opacity(isLoading ? 0 : 1)
        .overlay {
          if isLoading {
            LoadingDotsView(color: .white)
          }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(Color(red: 0.87, green: 0.0, blue: 0.35))
        .clipShape(.rect(cornerRadius: 10))
    }
    .disabled(isLoading)
  }
}

// MARK: - Preview

#Preview {
  EmailLoginView(
    showVerification: .constant(false),
    pendingVerification: .constant(nil),
    isLoading: .constant(false),
    errorMessage: .constant(nil)
  )
  .padding()
  .environment(Clerk.preview())
}
