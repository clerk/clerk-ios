//
//  TrustedDeviceEnrollmentView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct TrustedDeviceEnrollmentView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  private let biometryDisplayName: TrustedDeviceBiometryDisplayName
  private let token: AuthFlowPresentationToken

  @State private var error: Error?

  private var title: LocalizedStringKey {
    "Allow \(biometryDisplayName.value)"
  }

  private var subtitle: LocalizedStringKey {
    TrustedDeviceEnrollmentStrings.subtitle(
      applicationName: TrustedDeviceEnrollmentStrings.applicationName(for: clerk),
      biometryDisplayName: biometryDisplayName
    )
  }

  init(
    biometryDisplayName: TrustedDeviceBiometryDisplayName,
    token: AuthFlowPresentationToken
  ) {
    self.biometryDisplayName = biometryDisplayName
    self.token = token
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 32) {
        headerSection
        biometryIcon
        buttonSection
        SecuredByClerkView()
      }
      .padding(16)
    }
    .background(theme.colors.background)
    .clerkErrorPresenting($error)
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    .navigationBarBackButtonHidden()
    .toolbar(.visible, for: .navigationBar)
    .preGlassSolidNavBar()
    #endif
  }
}

extension TrustedDeviceEnrollmentView {
  private var headerSection: some View {
    VStack(spacing: 8) {
      HeaderView(style: .title, text: title)
      HeaderView(style: .subtitle, text: subtitle)
    }
  }

  @ViewBuilder
  private var biometryIcon: some View {
    if let systemImageName = biometryDisplayName.systemImageName {
      Image(systemName: systemImageName)
        .symbolRenderingMode(.palette)
        .foregroundStyle(theme.colors.primary, theme.colors.foreground)
        .font(.system(size: 64))
        .frame(maxWidth: .infinity)
        .frame(height: 175)
        .accessibilityHidden(true)
    }
  }

  private var buttonSection: some View {
    VStack(spacing: 24) {
      allowButton
      notNowButton
    }
  }

  private var allowButton: some View {
    AsyncButton {
      await enrollTrustedDevice()
    } label: { isRunning in
      Text("Allow", bundle: .module)
        .frame(maxWidth: .infinity)
        .overlayProgressView(isActive: isRunning) {
          SpinnerView(color: theme.colors.primaryForeground)
        }
    }
    .buttonStyle(.primary())
  }

  private var notNowButton: some View {
    Button {
      continueAfterEnrollmentPrompt()
    } label: {
      Text("Not now", bundle: .module)
    }
    .buttonStyle(.primary(config: .init(emphasis: .none, size: .small)))
  }

  private func enrollTrustedDevice() async {
    guard clerk.authFlowPresentationIsCurrent(token) else { return }
    error = nil

    do {
      try await clerk.trustedDevices.enroll(
        identifierHint: clerk.user?.trustedDeviceIdentifierHint,
        reason: enrollmentReason,
        policy: .biometryCurrentSet
      )
      guard clerk.authFlowPresentationIsCurrent(token) else { return }
      continueAfterEnrollmentPrompt()
    } catch {
      if error.isUserCancelledError {
        return
      }

      self.error = error
    }
  }

  private var enrollmentReason: String {
    TrustedDeviceEnrollmentStrings.enrollmentReason(
      applicationName: TrustedDeviceEnrollmentStrings.applicationName(for: clerk),
      biometryDisplayName: biometryDisplayName
    )
  }

  private func continueAfterEnrollmentPrompt() {
    _ = clerk.finishAuthFlowPresentation(token)
  }
}

#endif
