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
  @FocusState private var isEmailFieldFocused: Bool

  private var isValidEmail: Bool {
    let emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    return email.wholeMatch(of: emailRegex) != nil
  }

  var body: some View {
    VStack(spacing: 0) {
      EmailInputField(email: $email, isFocused: $isEmailFieldFocused)

      ContinueButton(
        isEnabled: isValidEmail,
        isLoading: isLoading
      ) {
        dismissKeyboard()
        submitEmail()
      }
      .padding(.top, 16)
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

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
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
    .frame(height: 56)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(Color(.systemGray4), lineWidth: 1)
    )
  }
}

// MARK: - ContinueButton

private struct ContinueButton: View {
  let isEnabled: Bool
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
        .frame(height: 56)
        .background(
          isEnabled
            ? Color(red: 0.87, green: 0.0, blue: 0.35)
            : Color(.systemGray4)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .disabled(!isEnabled || isLoading)
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
