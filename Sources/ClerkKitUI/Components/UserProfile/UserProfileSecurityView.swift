//
//  UserProfileSecurityView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct UserProfileSecurityView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(UserProfileSheetNavigation.self) private var navigation
  @State private var error: Error?

  @State private var biometricCredentialAvailability: BiometricCredentialAvailability?
  private let biometryDisplayName = BiometryDisplayName.current()

  private var user: User? {
    clerk.user
  }

  private var environment: Clerk.Environment? {
    clerk.environment
  }

  private var shouldShowDevices: Bool {
    guard let user else { return false }
    return (clerk.sessionsByUserId[user.id] ?? []).contains { $0.latestActivity != nil }
  }

  private var biometricCredentialFeatureIsEnabled: Bool {
    guard let nativeSettings = environment?.authConfig.nativeSettings else {
      return false
    }

    return nativeSettings.apiEnabled &&
      nativeSettings.biometricSignInEnabled &&
      biometryDisplayName.isSupported
  }

  private struct BiometricCredentialAvailabilityRefreshKey: Hashable {
    let sessionID: String
    let userID: String
  }

  private var biometricCredentialIsEnabled: Bool {
    if let biometricCredentialAvailability {
      return biometricCredentialAvailability.isAvailable
    }

    return localBiometricCredentialAvailability?.isAvailable == true
  }

  private var localBiometricCredentialAvailability: BiometricCredentialAvailability? {
    guard biometricCredentialFeatureIsEnabled else {
      return nil
    }

    return try? clerk.biometricCredentials.currentUserLocalAvailability()
  }

  private var biometricCredentialAvailabilityRefreshKey: BiometricCredentialAvailabilityRefreshKey? {
    guard biometricCredentialFeatureIsEnabled,
          let user,
          let sessionID = clerk.session?.id
    else {
      return nil
    }

    return BiometricCredentialAvailabilityRefreshKey(
      sessionID: sessionID,
      userID: user.id
    )
  }

  var body: some View {
    @Bindable var navigation = navigation

    Group {
      if let user {
        ScrollView {
          VStack(spacing: 0) {
            if environment?.passwordIsEnabled == true {
              UserProfilePasswordSection()
            }

            if biometricCredentialFeatureIsEnabled {
              UserProfileBiometricCredentialsSection(
                isEnabled: biometricCredentialIsEnabled,
                refreshAvailability: refreshBiometricCredentialAvailability
              )
            }

            if environment?.passkeyIsEnabled == true {
              UserProfilePasskeySection()
            }

            if environment?.mfaIsEnabled == true {
              UserProfileMfaSection()
            }

            if shouldShowDevices {
              UserProfileDevicesSection()
            }

            if environment?.deleteSelfIsEnabled == true {
              UserProfileDeleteAccountSection()
            }
          }
          .animation(.default, value: user)
          .animation(.default, value: clerk.sessionsByUserId)
          .animation(.default, value: environment)
        }
        .background(theme.colors.muted)
      }
    }
    .securedByClerkFooter()
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text("Security", bundle: .module)
          .font(theme.fonts.headline)
          .fontWeight(.semibold)
          .foregroundStyle(theme.colors.foreground)
      }
    }
    .presentationBackground(theme.colors.background)
    .background(theme.colors.background)
    .clerkErrorPresenting($error)
    .task {
      _ = try? await user?.getSessions()
    }
    .task(id: biometricCredentialAvailabilityRefreshKey) {
      refreshLocalBiometricCredentialAvailability()
      await refreshBiometricCredentialAvailability()
    }
    .task {
      _ = try? await clerk.refreshClient()
    }
    .sheet(item: $navigation.presentedAddMfaType) {
      $0.view
    }
    #if os(macOS)
    .frame(minWidth: 460, maxWidth: 620, alignment: .leading)
    #endif
  }
}

extension UserProfileSecurityView {
  @MainActor
  private func refreshLocalBiometricCredentialAvailability() {
    guard biometricCredentialFeatureIsEnabled else {
      biometricCredentialAvailability = nil
      return
    }

    do {
      biometricCredentialAvailability = try clerk.biometricCredentials.currentUserLocalAvailability()
    } catch {
      biometricCredentialAvailability = nil
      ClerkLogger.error("Failed to refresh local biometric-credential availability", error: error)
    }
  }

  @MainActor
  @discardableResult
  private func refreshBiometricCredentialAvailability() async -> BiometricCredentialAvailability? {
    guard biometricCredentialFeatureIsEnabled else {
      biometricCredentialAvailability = nil
      return nil
    }

    do {
      let availability = try await clerk.biometricCredentials.currentUserAvailability()
      biometricCredentialAvailability = availability
      return availability
    } catch {
      if error.isCancellationError {
        return nil
      } else {
        biometricCredentialAvailability = nil
        ClerkLogger.error("Failed to refresh biometric-credential availability", error: error)
      }
      return nil
    }
  }
}

#Preview {
  NavigationStack {
    UserProfileSecurityView()
  }
  .clerkPreview()
  .environment(UserProfileSheetNavigation())
  .environment(\.clerkTheme, .clerk)
}

#endif
