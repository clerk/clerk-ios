//
//  FinishSigningUpView.swift
//  AirbnbClone
//
//  Created by Mike Pitre on 12/15/25.
//

import ClerkKit
import SwiftUI

struct FinishSigningUpView: View {
  let identifierTitle: String
  let identifierValue: String
  let onContinue: (_ firstName: String, _ lastName: String, _ legalAccepted: Bool) async throws -> PendingVerification

  @State private var firstName = ""
  @State private var lastName = ""
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var showOTP = false
  @State private var pendingVerification: PendingVerification?

  private var canContinue: Bool {
    !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
      !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
      !isLoading
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Text("Legal name")
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(Color(uiColor: .label))
          .padding(.top, 16)

        NameInputCard(firstName: $firstName, lastName: $lastName)
          .padding(.top, 12)

        Text("Make sure this matches the name on your government ID.")
          .font(.system(size: 14))
          .foregroundStyle(.secondary)
          .padding(.top, 12)

        Text(identifierTitle)
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(Color(uiColor: .label))
          .padding(.top, 28)

        IdentifierReadOnlyField(title: identifierTitle, value: identifierValue)
          .padding(.top, 12)

        if let errorMessage {
          Text(errorMessage)
            .font(.system(size: 14))
            .foregroundStyle(.red)
            .padding(.top, 12)
        }

        Text("By selecting Agree and continue, you agree to our Terms of Service and acknowledge the Privacy Policy.")
          .font(.system(size: 14))
          .foregroundStyle(Color(uiColor: .label))
          .padding(.top, 28)

        Spacer(minLength: 24)
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 24)
    }
    .navigationTitle("Finish signing up")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbarBackground(Color(uiColor: .systemBackground), for: .navigationBar)
    .toolbarRole(.editor)
    .safeAreaInset(edge: .bottom) {
      VStack(spacing: 0) {
        Divider()
        AgreeAndContinueButton(isEnabled: canContinue, isLoading: isLoading) {
          submit()
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
      }
      .background(Color(uiColor: .systemBackground))
    }
    .sheet(isPresented: $showOTP) {
      if let pendingVerification {
        NavigationStack {
          OTPVerificationView(pending: pendingVerification)
        }
        .tint(Color(uiColor: .label))
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
      }
    }
  }

  private func submit() {
    Task {
      guard canContinue else { return }
      errorMessage = nil
      isLoading = true
      defer { isLoading = false }
      do {
        let pending = try await onContinue(
          firstName.trimmingCharacters(in: .whitespacesAndNewlines),
          lastName.trimmingCharacters(in: .whitespacesAndNewlines),
          true
        )
        pendingVerification = pending
        showOTP = true
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }
}

// MARK: - NameInputCard

private struct NameInputCard: View {
  @Binding var firstName: String
  @Binding var lastName: String

  var body: some View {
    VStack(spacing: 0) {
      TextField("First name on ID", text: $firstName)
        .textContentType(.givenName)
        .autocorrectionDisabled()
        .padding(.horizontal, 16)
        .padding(.vertical, 14)

      Divider()

      TextField("Last name on ID", text: $lastName)
        .textContentType(.familyName)
        .autocorrectionDisabled()
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    .background(
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(Color(uiColor: .separator), lineWidth: 1)
    )
  }
}

// MARK: - EmailReadOnlyField

private struct IdentifierReadOnlyField: View {
  let title: String
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.system(size: 12))
        .foregroundStyle(.secondary)

      TextField("", text: .constant(value))
        .font(.system(size: 16))
        .disabled(true)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(
      RoundedRectangle(cornerRadius: 10)
        .strokeBorder(Color(uiColor: .separator), lineWidth: 1)
    )
  }
}

// MARK: - AgreeAndContinueButton

private struct AgreeAndContinueButton: View {
  let isEnabled: Bool
  let isLoading: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Group {
        if isLoading {
          LoadingDotsView(color: .white)
        } else {
          Text("Agree and continue")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
        }
      }
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .background(isEnabled ? .black : Color(uiColor: .systemGray4))
      .clipShape(.rect(cornerRadius: 12))
    }
    .disabled(!isEnabled || isLoading)
  }
}

#Preview {
  FinishSigningUpView(identifierTitle: "Email", identifierValue: "mike@clerk.dev") { _, _, _ in
    .signIn(.mock)
  }
}
