//
//  UserProfileTrustedDeviceSection.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct UserProfileTrustedDeviceSection: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  let isEnabled: Bool
  let refreshAvailability: @MainActor () async -> TrustedDeviceAvailability?

  @State private var optimisticIsEnabled: Bool?
  @State private var isLoading = false
  @State private var error: Error?

  private let biometryDisplayName = TrustedDeviceBiometryDisplayName.current()

  private var user: User? {
    clerk.user
  }

  private var currentIsEnabled: Bool {
    optimisticIsEnabled ?? isEnabled
  }

  private var toggleBinding: Binding<Bool> {
    Binding {
      currentIsEnabled
    } set: { newValue in
      guard currentIsEnabled != newValue, !isLoading else {
        return
      }
      optimisticIsEnabled = newValue
      Task {
        await setTrustedDeviceSignInEnabled(newValue)
      }
    }
  }

  var body: some View {
    Section {
      HStack(spacing: 16) {
        if let systemImageName = biometryDisplayName.systemImageName {
          Image(systemName: systemImageName)
            .font(.system(size: 24))
            .frame(width: 24, height: 24)
            .foregroundStyle(theme.colors.mutedForeground)
        }

        Text("Sign in with \(biometryDisplayName.value)", bundle: .module)
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.foreground)
          .frame(minHeight: 22)

        Spacer(minLength: 0)

        Toggle("", isOn: toggleBinding)
          .labelsHidden()
          .tint(theme.colors.primary)
          .accessibilityLabel(Text("Sign in with \(biometryDisplayName.value)", bundle: .module))
          .accessibilityIdentifier(ClerkAccessibilityIdentifiers.UserProfile.Security.trustedDeviceToggle)
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 16)
      .background(theme.colors.background)
      .disabled(isLoading)
      .opacity(isLoading ? 0.55 : 1)
      .overlay(alignment: .bottom) {
        Rectangle()
          .frame(height: 1)
          .foregroundStyle(theme.colors.border)
      }
    } header: {
      UserProfileSectionHeader(verbatim: biometryDisplayName.value)
    }
    .clerkErrorPresenting($error)
  }
}

extension UserProfileTrustedDeviceSection {
  private var enrollmentReason: String {
    TrustedDeviceEnrollmentStrings.enrollmentReason(
      applicationName: TrustedDeviceEnrollmentStrings.applicationName(for: clerk),
      biometryDisplayName: biometryDisplayName
    )
  }

  private func setTrustedDeviceSignInEnabled(_ enabled: Bool) async {
    isLoading = true
    optimisticIsEnabled = enabled
    defer { isLoading = false }

    do {
      if enabled {
        try await clerk.trustedDevices.enroll(
          identifierHint: user?.trustedDeviceIdentifierHint,
          reason: enrollmentReason
        )
      } else {
        try await clerk.trustedDevices.revokeCurrentDeviceCredential(
          identifierHint: user?.trustedDeviceIdentifierHint
        )
      }

      if await refreshAvailability() != nil {
        optimisticIsEnabled = nil
      }
    } catch {
      _ = await refreshAvailability()
      optimisticIsEnabled = nil

      if error.isUserCancelledError {
        return
      }

      self.error = error
      ClerkLogger.error("Failed to update trusted-device sign-in", error: error)
    }
  }
}

#Preview {
  UserProfileTrustedDeviceSection(
    isEnabled: true,
    refreshAvailability: { .available }
  )
    .clerkPreview()
    .environment(\.clerkTheme, .clerk)
}

#endif
