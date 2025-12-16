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

  @State private var pending: PendingVerification

  @State private var code = ""
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var canResend = false
  @State private var resendCountdown = 30
  @FocusState private var isCodeFieldFocused: Bool
  @State private var isVerifying = false

  init(pending: PendingVerification) {
    _pending = State(initialValue: pending)
  }

  private var identifierRaw: String {
    switch pending {
    case .signIn(let signIn):
      signIn.identifier ?? ""
    case .signUp(let signUp, _):
      signUp.emailAddress ?? signUp.phoneNumber ?? ""
    }
  }

  private var subtitle: String {
    if identifierRaw.first == "+" {
      let utility = PhoneNumberUtility()
      if let phoneNumber = try? utility.parse(identifierRaw) {
        let formatted = utility.format(phoneNumber, toType: .international)
        let withoutPlus = formatted
          .trimmingCharacters(in: .whitespacesAndNewlines)
          .replacingOccurrences(of: "+", with: "")
        return "Enter the code we sent over SMS to \(withoutPlus):"
      }
    }
    return "Enter the code we sent over SMS to \(identifierRaw):"
  }

  private var canContinue: Bool {
    code.count == 6 && !isLoading && !isVerifying
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(subtitle)
        .font(.system(size: 16))
        .foregroundStyle(.secondary)
        .padding(.top, 16)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)

      codeField
        .padding(.horizontal, 24)

      if let errorMessage {
        Text(errorMessage)
          .font(.system(size: 14))
          .foregroundStyle(.red)
          .padding(.horizontal, 24)
          .padding(.top, 12)
      }

      VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 0) {
          Text("Didn't get an SMS? ")
            .font(.system(size: 16))
            .foregroundStyle(.secondary)

          Button {
            resendCode()
          } label: {
            Text("Send again")
              .font(.system(size: 16, weight: .semibold))
              .underline()
              .foregroundStyle(.primary)
          }
          .buttonStyle(.plain)
          .disabled(!canResend || isLoading)
          .opacity(canResend ? 1 : 0.45)
        }
      }
      .padding(.top, 24)
      .padding(.horizontal, 24)

      Spacer(minLength: 0)
    }
    .navigationTitle("Confirm your number")
    .navigationBarTitleDisplayMode(.inline)
    .navigationBarBackButtonHidden()
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbarBackground(Color(uiColor: .systemBackground), for: .navigationBar)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          dismiss()
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color(uiColor: .label))
        }
        .buttonStyle(.plain)
      }
    }
    .safeAreaInset(edge: .bottom) {
      Button {
        verifyCode()
      } label: {
        Group {
          if isLoading || isVerifying {
            LoadingDotsView(color: .white)
          } else {
            Text("Continue")
              .font(.system(size: 17, weight: .semibold))
              .foregroundStyle(.white)
          }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(
          canContinue
            ? Color(red: 0.87, green: 0.0, blue: 0.35)
            : Color(uiColor: .systemGray4)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
      }
      .disabled(!canContinue)
      .padding(.horizontal, 24)
      .padding(.top, 12)
      .padding(.bottom, 12)
      .background(Color(uiColor: .systemBackground))
    }
    .overlay {
      if isLoading {
        EmptyView()
      }
    }
    .task {
      await Task.yield()
      isCodeFieldFocused = true
      startResendTimer()
    }
  }

  private func digitAt(index: Int) -> String {
    guard index < code.count else { return "" }
    let codeArray = Array(code)
    return String(codeArray[index])
  }

  private var codeField: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(
          isCodeFieldFocused ? Color(uiColor: .systemGray2) : Color(uiColor: .systemGray3),
          lineWidth: 2
        )
        .frame(height: 72)

      HStack(spacing: 18) {
        ForEach(0 ..< 6, id: \.self) { index in
          Text(digitAt(index: index).isEmpty ? "-" : digitAt(index: index))
            .font(.system(size: 24, weight: .medium))
            .foregroundStyle(.primary)
            .frame(width: 20)
        }
      }
      .monospaced()
    }
    .contentShape(Rectangle())
    .onTapGesture { isCodeFieldFocused = true }
    .background(hiddenCodeField)
  }

  private var hiddenCodeField: some View {
    // Keep the actual TextField out of the visible box so we don't render a caret/cursor.
    TextField("", text: $code)
      .keyboardType(.numberPad)
      .textContentType(.oneTimeCode)
      .focused($isCodeFieldFocused)
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
          verifyCode()
        }
      }
  }

  private func verifyCode() {
    guard !isVerifying else { return }
    Task {
      isLoading = true
      isVerifying = true
      errorMessage = nil
      do {
        switch pending {
        case .signIn(let signIn):
          pending = try await .signIn(signIn.verifyCode(code))
        case .signUp(let signUp, let type):
          pending = try await .signUp(signUp.verifyCode(code, type: type), type)
        }
        // Navigation will be handled by the Clerk environment observing the user state
      } catch {
        errorMessage = error.localizedDescription
        code = ""
      }
      isLoading = false
      isVerifying = false
    }
  }

  private func resendCode() {
    Task {
      isLoading = true
      errorMessage = nil
      do {
        switch pending {
        case .signIn(let signIn):
          // Resend based on the verification strategy
          if signIn.firstFactorVerification?.strategy == .emailCode {
            pending = try await .signIn(signIn.sendEmailCode())
          } else {
            pending = try await .signIn(signIn.sendPhoneCode())
          }
        case .signUp(let signUp, let type):
          switch type {
          case .email:
            pending = try await .signUp(signUp.sendEmailCode(), type)
          case .phone:
            pending = try await .signUp(signUp.sendPhoneCode(), type)
          }
        }
        resendCountdown = 30
        canResend = false
        startResendTimer()
      } catch {
        errorMessage = error.localizedDescription
      }
      isLoading = false
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

#Preview {
  NavigationStack {
    OTPVerificationView(pending: .signIn(.mock))
  }
  .environment(Clerk.preview())
}
