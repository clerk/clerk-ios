//
//  SessionTaskMfaAddPhoneView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SessionTaskMfaAddPhoneView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(AuthNavigation.self) private var navigation
  @Environment(\.clerkTheme) private var theme
  @Environment(CodeLimiter.self) private var codeLimiter

  @State private var phoneNumber = ""
  @State private var error: Error?

  @FocusState private var isFocused: Bool

  private var user: User? {
    clerk.user
  }

  var body: some View {
    ScrollView {
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
    .clerkErrorPresenting($error)
    .background(theme.colors.background)
    .navigationBarTitleDisplayMode(.inline)
    .preGlassSolidNavBar()
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        UserButton(presentationContext: .sessionTaskToolbar)
      }
    }
  }

  private func addPhoneNumber() async {
    guard let user else { return }

    do {
      let newPhoneNumber = try await user.createPhoneNumber(phoneNumber)
      try await newPhoneNumber.sendCode()
      codeLimiter.recordCodeSent(for: newPhoneNumber.phoneNumber)
      navigation.path.append(.taskVerifySms(phoneNumber: newPhoneNumber))
    } catch {
      self.error = error
      ClerkLogger.error("Failed to add phone number", error: error)
    }
  }
}

#endif
