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
  @State private var isReservingForSecondFactor = false
  @State private var selectedPhoneNumber: PhoneNumber?

  private var user: User? {
    clerk.user
  }

  private var availablePhoneNumbers: [PhoneNumber] {
    (user?.phoneNumbersAvailableForMfa ?? [])
      .sorted { $0.createdAt < $1.createdAt }
  }

  var body: some View {
    ScrollView {
      if (availablePhoneNumbers.isEmpty && !isReservingForSecondFactor) || isSubmittingPhone {
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
      isReservingForSecondFactor = false
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
          Button {
            selectedPhoneNumber = phoneNumber
          } label: {
            AddMfaSmsRow(
              phoneNumber: phoneNumber,
              isSelected: selectedPhoneNumber == phoneNumber
            )
          }
          .buttonStyle(.pressedBackground)
        }
      }
      .padding(.bottom, 24)

      AsyncButton {
        guard let selectedPhoneNumber else { return }
        await continueWithPhoneNumber(selectedPhoneNumber)
      } label: { isRunning in
        ContinueButtonLabelView(isActive: isRunning)
      }
      .buttonStyle(.primary())
      .disabled(selectedPhoneNumber == nil)
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
    .sensoryFeedback(.selection, trigger: selectedPhoneNumber)
  }

  private func continueWithPhoneNumber(_ phoneNumber: PhoneNumber) async {
    if phoneNumber.verification?.status == .verified {
      isReservingForSecondFactor = true
      do {
        let reserved = try await phoneNumber.setReservedForSecondFactor()
        if let backupCodes = reserved.backupCodes, !backupCodes.isEmpty {
          navigation.path.append(.backupCodes(backupCodes: backupCodes, mfaType: .phoneCode))
        } else {
          navigation.handleSessionTaskCompletion(session: clerk.session)
        }
      } catch {
        isReservingForSecondFactor = false
        self.error = error
        ClerkLogger.error("Failed to reserve phone number for second factor", error: error)
      }
    } else {
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
}

#endif
