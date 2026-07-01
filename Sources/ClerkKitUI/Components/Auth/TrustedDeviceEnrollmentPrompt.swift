//
//  TrustedDeviceEnrollmentPrompt.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import Foundation

extension TransferFlowResult {
  func shouldOfferTrustedDeviceEnrollmentPrompt(
    userID: String,
    promptStore: TrustedDeviceEnrollmentPromptStore
  ) -> Bool {
    switch self {
    case .signIn:
      !promptStore.hasSeenPrompt(userID: userID)
    case .signUp:
      true
    }
  }
}

struct TrustedDeviceEnrollmentPromptStore {
  private let userDefaults: UserDefaults

  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
  }

  func hasSeenPrompt(userID: String) -> Bool {
    userDefaults.bool(forKey: storageKey(userID: userID))
  }

  func markPromptSeen(userID: String) {
    userDefaults.set(true, forKey: storageKey(userID: userID))
  }

  func clearPromptSeen(userID: String) {
    userDefaults.removeObject(forKey: storageKey(userID: userID))
  }

  private func storageKey(userID: String) -> String {
    "\(Self.storageKeyPrefix).\(userID)"
  }

  private static let storageKeyPrefix = "clerk_trusted_device_enrollment_prompt_seen"
}

#endif
