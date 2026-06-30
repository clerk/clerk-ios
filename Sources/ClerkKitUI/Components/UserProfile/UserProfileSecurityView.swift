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

  #if os(iOS)
  @State private var trustedDeviceAvailability: TrustedDeviceAvailability?
  private let biometryDisplayName = TrustedDeviceBiometryDisplayName.current()
  #endif

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

  #if os(iOS)
  private var trustedDeviceFeatureIsEnabled: Bool {
    guard let nativeSettings = environment?.authConfig.nativeSettings else {
      return false
    }

    return nativeSettings.apiEnabled &&
      nativeSettings.trustedDeviceSignInEnabled &&
      biometryDisplayName.isSupported
  }

  private struct TrustedDeviceAvailabilityRefreshKey: Hashable {
    let sessionID: String
    let userID: String
    let identifierHint: String?
  }

  private var trustedDeviceAvailabilityRefreshKey: TrustedDeviceAvailabilityRefreshKey? {
    guard trustedDeviceFeatureIsEnabled,
          let user,
          let sessionID = clerk.session?.id
    else {
      return nil
    }

    return TrustedDeviceAvailabilityRefreshKey(
      sessionID: sessionID,
      userID: user.id,
      identifierHint: user.trustedDeviceIdentifierHint
    )
  }
  #endif

  var body: some View {
    @Bindable var navigation = navigation

    Group {
      if let user {
        ScrollView {
          VStack(spacing: 0) {
            if environment?.passwordIsEnabled == true {
              UserProfilePasswordSection()
            }

            #if os(iOS)
            if trustedDeviceFeatureIsEnabled {
              UserProfileTrustedDeviceSection(
                isEnabled: trustedDeviceAvailability?.isAvailable,
                refreshAvailability: refreshTrustedDeviceAvailability
              )
            }
            #endif

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
    #if os(iOS)
    .task(id: trustedDeviceAvailabilityRefreshKey) {
      refreshLocalTrustedDeviceAvailability()
      await refreshTrustedDeviceAvailability()
    }
    #endif
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

#if os(iOS)
extension UserProfileSecurityView {
  @MainActor
  private func refreshLocalTrustedDeviceAvailability() {
    guard trustedDeviceFeatureIsEnabled, let user else {
      trustedDeviceAvailability = nil
      return
    }

    do {
      trustedDeviceAvailability = try clerk.trustedDevices.localAvailability(
        identifierHint: user.trustedDeviceIdentifierHint
      )
    } catch {
      trustedDeviceAvailability = nil
      ClerkLogger.error("Failed to refresh local trusted-device availability", error: error)
    }
  }

  @MainActor
  @discardableResult
  private func refreshTrustedDeviceAvailability() async -> TrustedDeviceAvailability? {
    guard trustedDeviceFeatureIsEnabled, let user else {
      trustedDeviceAvailability = nil
      return nil
    }

    do {
      let availability = try await clerk.trustedDevices.availability(
        identifierHint: user.trustedDeviceIdentifierHint
      )
      trustedDeviceAvailability = availability
      return availability
    } catch {
      if error.isCancellationError {
        return nil
      } else {
        ClerkLogger.error("Failed to refresh trusted-device availability", error: error)
      }
      return nil
    }
  }
}
#endif

#Preview {
  NavigationStack {
    UserProfileSecurityView()
  }
  .clerkPreview()
  .environment(UserProfileSheetNavigation())
  .environment(\.clerkTheme, .clerk)
}

#endif
