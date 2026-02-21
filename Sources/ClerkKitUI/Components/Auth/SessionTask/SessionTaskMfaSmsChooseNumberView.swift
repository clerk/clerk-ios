//
//  SessionTaskMfaSmsChooseNumberView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SessionTaskMfaSmsChooseNumberView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(CodeLimiter.self) private var codeLimiter

  @State private var phoneNumberToVerify: ClerkKit.PhoneNumber?
  @State private var showVerifySms = false
  @State private var showAddPhone = false
  @State private var error: Error?

  let onDone: () -> Void

  private var user: User? {
    clerk.user
  }

  private var availablePhoneNumbers: [ClerkKit.PhoneNumber] {
    (user?.phoneNumbersAvailableForMfa ?? [])
      .filter { $0.verification?.status == .verified }
      .sorted { $0.createdAt < $1.createdAt }
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        Badge(key: "Two-step verification setup", style: .secondary)
          .padding(.bottom, 16)

        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Add SMS code verification")
          HeaderView(style: .subtitle, text: "Choose the phone number you want to use for SMS code two-step verification")
        }
        .padding(.bottom, 32)

        VStack(spacing: 12) {
          ForEach(availablePhoneNumbers) { phoneNumber in
            AsyncButton {
              await sendCode(to: phoneNumber)
            } label: { isRunning in
              AddMfaSmsRow(
                phoneNumber: phoneNumber,
                isSelected: false
              )
              .overlayProgressView(isActive: isRunning)
            }
            .buttonStyle(.pressedBackground)
          }
        }
        .padding(.bottom, 24)

        Button {
          showAddPhone = true
        } label: {
          Text("Add phone number", bundle: .module)
        }
        .buttonStyle(
          .primary(
            config: .init(
              emphasis: .none,
              size: .small
            )
          )
        )
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
    .navigationDestination(isPresented: $showAddPhone) {
      SessionTaskMfaAddPhoneView(onDone: onDone)
    }
    .navigationDestination(isPresented: $showVerifySms) {
      if let phoneNumberToVerify {
        SessionTaskMfaVerifySmsView(
          phoneNumber: phoneNumberToVerify,
          onDone: onDone
        )
      }
    }
  }

  private func sendCode(to phoneNumber: ClerkKit.PhoneNumber) async {
    do {
      try await phoneNumber.sendCode()
      codeLimiter.recordCodeSent(for: phoneNumber.phoneNumber)
      phoneNumberToVerify = phoneNumber
      showVerifySms = true
    } catch {
      self.error = error
      ClerkLogger.error("Failed to send SMS code", error: error)
    }
  }
}

#endif
