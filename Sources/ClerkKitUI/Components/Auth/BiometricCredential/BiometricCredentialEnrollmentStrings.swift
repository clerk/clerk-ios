//
//  BiometricCredentialEnrollmentStrings.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import Foundation
import SwiftUI

enum BiometricCredentialEnrollmentStrings {
  @MainActor
  static func applicationName(for clerk: Clerk) -> String? {
    guard let applicationName = clerk.environment?.displayConfig.applicationName,
          !applicationName.isEmptyTrimmed
    else {
      return nil
    }
    return applicationName
  }

  static func subtitle(
    applicationName: String?,
    biometryDisplayName: BiometryDisplayName
  ) -> LocalizedStringKey {
    if let applicationName {
      return "Enable \(biometryDisplayName.value) for faster access to \(applicationName)"
    }

    return "Enable \(biometryDisplayName.value) for faster access"
  }

  static func enrollmentReason(
    applicationName: String?,
    biometryDisplayName: BiometryDisplayName
  ) -> String {
    if let applicationName {
      return String(
        localized: "The app \(applicationName) uses \(biometryDisplayName.value) to sign you in.",
        bundle: .module
      )
    }

    return String(
      localized: "Use \(biometryDisplayName.value) to sign in.",
      bundle: .module
    )
  }
}

#endif
