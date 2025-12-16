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
  @State private var showFinishSigningUp = false
  @State private var pendingSignUp: SignUp?

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

      if let errorMessage {
        HStack(spacing: 6) {
          Image(systemName: "exclamationmark.circle.fill")
            .font(.system(size: 14))
          Text(errorMessage)
            .font(.system(size: 14))
        }
        .foregroundStyle(Color(red: 0.76, green: 0.15, blue: 0.18))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
        .transition(.opacity)
      }

      EmailContinueButton(isLoading: isLoading) {
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
    .navigationDestination(isPresented: $showFinishSigningUp) {
      FinishSigningUpView(identifierTitle: "Email", identifierValue: email) { firstName, lastName, legalAccepted in
        guard let signUp = pendingSignUp else {
          throw ClerkClientError(message: "Unable to continue sign up: missing sign up state.")
        }
        let updated = try await signUp.update(
          firstName: firstName,
          lastName: lastName,
          legalAccepted: legalAccepted
        )
        let prepared = try await updated.sendEmailCode()
        pendingSignUp = nil
        return .signUp(prepared, .email)
      }
      .onDisappear {
        pendingSignUp = nil
      }
    }
  }

  private func submitEmail() {
    Task {
      errorMessage = nil
      isLoading = true
      defer { isLoading = false }
      pendingVerification = nil
      showVerification = false
      do {
        let signUp = try await clerk.auth.signUp(emailAddress: email)
        pendingSignUp = signUp
        showFinishSigningUp = true
      } catch {
        do {
          let signIn = try await clerk.auth.signInWithEmailCode(emailAddress: email)
          pendingVerification = .signIn(signIn)
          showVerification = true
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
