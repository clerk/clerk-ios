//
//  SessionTaskAddPhoneForm.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SessionTaskAddPhoneForm: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  @State private var phoneNumber = ""
  @State private var error: Error?

  @FocusState private var isFocused: Bool

  var onBeginSubmit: (() -> Void)?
  var onError: (() -> Void)?
  let onPhoneNumberCreated: (PhoneNumber) async throws -> Void

  private var user: User? {
    clerk.user
  }

  var body: some View {
    VStack(spacing: 0) {
      SessionTaskHeaderSection(
        title: "Add phone number",
        subtitle: "A text message containing a verification code will be sent to this phone number. Message and data rates may apply."
      )
      .padding(.bottom, 32)

      VStack(spacing: 24) {
        VStack(spacing: 4) {
          ClerkPhoneNumberField("Enter your phone number", text: $phoneNumber)
            .textContentType(.telephoneNumber)
            .keyboardType(.numberPad)
            .focused($isFocused)
            .onFirstAppear {
              isFocused = true
            }

          if let error {
            ErrorText(error: error, alignment: .leading)
              .font(theme.fonts.subheadline)
              .transition(.blurReplace.animation(.default))
              .id(error.localizedDescription)
          }
        }

        AsyncButton {
          await addPhoneNumber()
        } label: { isRunning in
          ContinueButtonLabelView(isActive: isRunning)
        }
        .buttonStyle(.primary())
      }
      .padding(.bottom, 32)

      SecuredByClerkView()
    }
    .padding(16)
  }

  private func addPhoneNumber() async {
    guard let user else { return }

    do {
      onBeginSubmit?()
      let newPhoneNumber = try await user.createPhoneNumber(phoneNumber)
      try await onPhoneNumberCreated(newPhoneNumber)
    } catch {
      self.error = error
      onError?()
      ClerkLogger.error("Failed to add phone number", error: error)
    }
  }
}

#endif
