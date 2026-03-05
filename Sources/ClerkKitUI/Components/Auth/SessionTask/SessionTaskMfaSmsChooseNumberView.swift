//
//  SessionTaskMfaSmsChooseNumberView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SessionTaskMfaSmsChooseNumberView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(AuthNavigation.self) private var navigation
  @Environment(\.clerkTheme) private var theme
  @Environment(CodeLimiter.self) private var codeLimiter

  @State private var error: Error?
  @State private var isSubmittingPhone = false
  @State private var didNavigateAway = false
  @State private var addPhoneNumberIsPresented = false

  private var user: User? {
    clerk.user
  }

  private var availablePhoneNumbers: [PhoneNumber] {
    (user?.phoneNumbersAvailableForMfa ?? [])
      .sorted { $0.createdAt < $1.createdAt }
  }

  var body: some View {
    ScrollView {
      if availablePhoneNumbers.isEmpty || isSubmittingPhone {
        addPhoneContent
      } else {
        chooseNumberContent
      }
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
    .onChange(of: navigation.path) { oldPath, newPath in
      if newPath.count > oldPath.count {
        didNavigateAway = true
      }
    }
    .onDisappear {
      guard didNavigateAway else { return }
      didNavigateAway = false
      isSubmittingPhone = false
    }
    .sheet(isPresented: $addPhoneNumberIsPresented) {
      NavigationStack {
        ScrollView {
          SessionTaskAddPhoneForm { _ in
            addPhoneNumberIsPresented = false
          }
        }
        .background(theme.colors.background)
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            DismissButton()
          }
        }
      }
      .presentationBackground(theme.colors.background)
      .tint(theme.colors.primary)
    }
  }

  private var addPhoneContent: some View {
    SessionTaskAddPhoneForm(
      onBeginSubmit: { isSubmittingPhone = true },
      onError: { isSubmittingPhone = false },
      onPhoneNumberCreated: { newPhoneNumber in
        try await newPhoneNumber.sendCode()
        codeLimiter.recordCodeSent(for: newPhoneNumber.phoneNumber)
        navigation.path.append(.taskVerifySms(phoneNumber: newPhoneNumber))
      }
    )
  }

  private var chooseNumberContent: some View {
    VStack(spacing: 0) {
      SessionTaskHeaderSection(
        title: "Add SMS code verification",
        subtitle: "Choose the phone number you want to use for SMS code two-step verification"
      )
      .padding(.bottom, 32)

      VStack(spacing: 12) {
        ForEach(availablePhoneNumbers) { phoneNumber in
          AsyncButton(
            action: {
              await sendCode(to: phoneNumber)
            },
            label: { isRunning in
              AddMfaSmsRow(
                phoneNumber: phoneNumber,
                isSelected: false
              )
              .overlayProgressView(isActive: isRunning)
            }
          )
          .buttonStyle(.pressedBackground)
        }
      }
      .padding(.bottom, 24)

      Button {
        addPhoneNumberIsPresented = true
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

  private func sendCode(to phoneNumber: PhoneNumber) async {
    do {
      try await phoneNumber.sendCode()
      codeLimiter.recordCodeSent(for: phoneNumber.phoneNumber)
      navigation.path.append(.taskVerifySms(phoneNumber: phoneNumber))
    } catch {
      self.error = error
      ClerkLogger.error("Failed to send SMS code", error: error)
    }
  }
}

#endif
