//
//  OTPVerificationView.swift
//  AirbnbClone
//
//  Created by Mike Pitre on 12/15/25.
//

import ClerkKit
import PhoneNumberKit
import SwiftUI

struct OTPVerificationView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(Clerk.self) private var clerk

  let loginMode: LoginMode

  @State private var code = ""
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var canResend = false
  @State private var resendCountdown = 30
  @FocusState private var isCodeFieldFocused: Bool
  @State private var isVerifying = false

  private var signIn: SignIn? {
    clerk.client?.signIn
  }

  private var signUp: SignUp? {
    clerk.client?.signUp
  }

  private var formattedIdentifier: String {
    guard loginMode.method == .phone, identifierRaw.first == "+" else { return identifierRaw }
    if let phoneNumber = try? phoneNumberUtility.parse(identifierRaw) {
      let formatted = phoneNumberUtility.format(phoneNumber, toType: .international)
      return formatted
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacing("+", with: "")
    }
    return identifierRaw
  }

  private var identifierRaw: String {
    if case .signUp = loginMode, let signUp {
      return signUp.emailAddress ?? signUp.phoneNumber ?? ""
    }
    if let signIn {
      return signIn.identifier ?? ""
    }
    return ""
  }

  private var navigationTitle: String {
    switch loginMode.method {
    case .email:
      "Confirm your email"
    case .phone:
      "Confirm your number"
    }
  }

  private var subtitle: String {
    switch loginMode.method {
    case .email:
      "Enter the code we sent over email to \(formattedIdentifier):"
    case .phone:
      "Enter the code we sent over SMS to \(formattedIdentifier):"
    }
  }

  private var canContinue: Bool {
    code.count == 6 && !isLoading && !isVerifying
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      OTPSubtitleText(subtitle: subtitle)
        .padding(.top, 16)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)

      OTPCodeField(
        code: $code,
        isFocused: $isCodeFieldFocused,
        onCodeComplete: verifyCode
      )
      .padding(.horizontal, 24)

      OTPErrorMessage(message: errorMessage)
        .padding(.horizontal, 24)
        .padding(.top, 12)

      ResendCodeSection(
        canResend: canResend,
        isLoading: isLoading,
        isEmail: loginMode.method == .email,
        onResend: resendCode
      )
      .padding(.top, 24)
      .padding(.horizontal, 24)

      Spacer(minLength: 0)
    }
    .navigationTitle(navigationTitle)
    .navigationBarTitleDisplayMode(.inline)
    .navigationBarBackButtonHidden()
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbarBackground(Color(uiColor: .systemBackground), for: .navigationBar)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        CloseButton {
          dismissKeyboard()
          dismiss()
        }
      }
    }
    .safeAreaInset(edge: .bottom) {
      VStack(spacing: 0) {
        Divider()

        OTPContinueButton(
          canContinue: canContinue,
          isLoading: isLoading || isVerifying
        ) {
          dismissKeyboard()
          verifyCode()
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
      }
      .background(Color(uiColor: .systemBackground))
    }
    .task {
      await Task.yield()
      isCodeFieldFocused = true
      startResendTimer()
    }
  }

  private func verifyCode() {
    guard !isVerifying else { return }
    Task {
      dismissKeyboard()
      isLoading = true
      isVerifying = true
      errorMessage = nil
      defer {
        isLoading = false
        isVerifying = false
      }

      do {
        if case .signUp = loginMode, let signUp {
          switch loginMode.method {
          case .email:
            try await signUp.verifyEmailCode(code)
          case .phone:
            try await signUp.verifyPhoneCode(code)
          }
        } else if let signIn {
          try await signIn.verifyCode(code)
        }
      } catch {
        errorMessage = error.localizedDescription
        code = ""
      }
    }
  }

  private func resendCode() {
    Task {
      errorMessage = nil
      isLoading = true
      defer { isLoading = false }

      do {
        if case .signUp = loginMode, let signUp {
          switch loginMode.method {
          case .email:
            try await signUp.sendEmailCode()
          case .phone:
            try await signUp.sendPhoneCode()
          }
        } else if let signIn {
          switch loginMode.method {
          case .email:
            try await signIn.sendEmailCode()
          case .phone:
            try await signIn.sendPhoneCode()
          }
        }
        resendCountdown = 30
        canResend = false
        startResendTimer()
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }

  private func startResendTimer() {
    Task {
      while resendCountdown > 0 {
        try? await Task.sleep(for: .seconds(1))
        resendCountdown -= 1
      }
      canResend = true
    }
  }
}

// MARK: - OTPSubtitleText

private struct OTPSubtitleText: View {
  let subtitle: String

  var body: some View {
    Text(subtitle)
      .font(.system(size: 17))
      .foregroundStyle(Color(uiColor: .label))
  }
}

// MARK: - OTPCodeField

private struct OTPCodeField: View {
  @Binding var code: String
  var isFocused: FocusState<Bool>.Binding
  let onCodeComplete: () -> Void

  var body: some View {
    ZStack {
      OTPCodeFieldBorder()
      OTPDigitsDisplay(code: code)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 72)
    .contentShape(.rect)
    .onTapGesture { isFocused.wrappedValue = true }
    .background(
      HiddenCodeTextField(
        code: $code,
        isFocused: isFocused,
        onCodeComplete: onCodeComplete
      )
    )
  }
}

// MARK: - OTPCodeFieldBorder

private struct OTPCodeFieldBorder: View {
  var body: some View {
    RoundedRectangle(cornerRadius: 12)
      .strokeBorder(Color(uiColor: .label), lineWidth: 2)
  }
}

// MARK: - OTPDigitsDisplay

private struct OTPDigitsDisplay: View {
  let code: String

  var body: some View {
    HStack(spacing: 24) {
      ForEach(0 ..< 6, id: \.self) { index in
        OTPDigitCell(digit: digitAt(index: index))
      }
    }
    .monospaced()
  }

  private func digitAt(index: Int) -> String {
    guard index < code.count else { return "" }
    let codeArray = Array(code)
    return String(codeArray[index])
  }
}

// MARK: - OTPDigitCell

private struct OTPDigitCell: View {
  let digit: String

  var body: some View {
    Text(digit.isEmpty ? "-" : digit)
      .font(.system(size: 24, weight: .medium))
      .foregroundStyle(digit.isEmpty ? Color(uiColor: .systemGray2) : Color(uiColor: .label))
      .frame(width: 20)
  }
}

// MARK: - HiddenCodeTextField

private struct HiddenCodeTextField: View {
  @Binding var code: String
  var isFocused: FocusState<Bool>.Binding
  let onCodeComplete: () -> Void

  var body: some View {
    TextField("", text: $code)
      .keyboardType(.numberPad)
      .textContentType(.oneTimeCode)
      .focused(isFocused)
      .frame(width: 1, height: 1)
      .opacity(0)
      .accessibilityHidden(true)
      .onChange(of: code) { _, newValue in
        let digits = newValue.filter(\.isWholeNumber)
        let clipped = String(digits.prefix(6))
        if code != clipped {
          code = clipped
        }
        if clipped.count == 6 {
          onCodeComplete()
        }
      }
  }
}

// MARK: - OTPErrorMessage

private struct OTPErrorMessage: View {
  let message: String?

  var body: some View {
    if let message {
      Text(message)
        .font(.system(size: 14))
        .foregroundStyle(.red)
    }
  }
}

// MARK: - ResendCodeSection

private struct ResendCodeSection: View {
  let canResend: Bool
  let isLoading: Bool
  let isEmail: Bool
  let onResend: () -> Void

  var body: some View {
    HStack(spacing: 0) {
      Text(isEmail ? "Didn't get an email? " : "Didn't get an SMS? ")
        .font(.system(size: 17))
        .foregroundStyle(Color(uiColor: .label))

      Button(action: onResend) {
        Text("Send again")
          .font(.system(size: 17, weight: .semibold))
          .underline()
          .foregroundStyle(Color(uiColor: .label))
      }
      .buttonStyle(.plain)
      .disabled(!canResend || isLoading)
      .opacity(canResend ? 1 : 0.35)
    }
  }
}

// MARK: - OTPContinueButton

private struct OTPContinueButton: View {
  let canContinue: Bool
  let isLoading: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Group {
        if isLoading {
          LoadingDotsView(color: .white)
        } else {
          Text("Continue")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
        }
      }
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .background(canContinue || isLoading ? .black : Color(uiColor: .systemGray4))
      .clipShape(.rect(cornerRadius: 12))
    }
    .disabled(!canContinue || isLoading)
  }
}

// MARK: - Preview

#Preview {
  NavigationStack {
    OTPVerificationView(loginMode: .signIn(method: .phone))
  }
  .environment(Clerk.preview())
}
