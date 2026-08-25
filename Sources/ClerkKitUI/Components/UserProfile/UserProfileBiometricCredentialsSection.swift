//
//  UserProfileBiometricCredentialsSection.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct UserProfileBiometricCredentialsSection: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  let isEnabled: Bool
  let refreshAvailability: @MainActor () async -> BiometricCredentialAvailability?

  @State private var optimisticIsEnabled: Bool?
  @State private var isLoading = false
  @State private var error: Error?

  private let biometryDisplayName = BiometryDisplayName.current()

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
      guard currentIsEnabled != newValue,
            !isLoading
      else {
        return
      }
      isLoading = true
      optimisticIsEnabled = newValue
      Task {
        await setBiometricSignInEnabled(newValue)
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
          .tint(theme.colors.switchTint)
          .accessibilityLabel(Text("Sign in with \(biometryDisplayName.value)", bundle: .module))
          .accessibilityIdentifier(ClerkAccessibilityIdentifiers.UserProfile.Security.biometricCredentialToggle)
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

extension UserProfileBiometricCredentialsSection {
  private var enrollmentReason: String {
    BiometricCredentialEnrollmentStrings.enrollmentReason(
      applicationName: BiometricCredentialEnrollmentStrings.applicationName(for: clerk),
      biometryDisplayName: biometryDisplayName
    )
  }

  private func setBiometricSignInEnabled(_ enabled: Bool) async {
    guard let user else {
      optimisticIsEnabled = nil
      isLoading = false
      return
    }

    optimisticIsEnabled = enabled
    defer { isLoading = false }

    do {
      if enabled {
        try await clerk.biometricCredentials.enroll(
          identifierHint: user.biometricCredentialIdentifierHint,
          reason: enrollmentReason,
          policy: .biometryCurrentSet
        )
      } else {
        try await clerk.biometricCredentials.revokeCurrentDeviceCredential()
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
      ClerkLogger.error("Failed to update biometric sign-in", error: error)
    }
  }
}

#Preview {
  UserProfileBiometricCredentialsSection(
    isEnabled: true,
    refreshAvailability: { .available }
  )
    .clerkPreview()
    .environment(\.clerkTheme, .clerk)
}

#endif
