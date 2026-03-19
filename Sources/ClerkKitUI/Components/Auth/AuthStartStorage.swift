//
//  AuthStartStorage.swift
//  Clerk
//

#if os(iOS)

import Foundation

/// Centralizes read/write/clear operations for the auth start prefill state
/// stored in `UserDefaults`.
///
/// Two keys are managed:
/// - `authStartIdentifier`: Email or username value.
/// - `authStartPhoneNumber`: Phone number value.
enum AuthStartStorage {
  private static let identifierKey = "authStartIdentifier"
  private static let phoneNumberKey = "authStartPhoneNumber"

  struct PrefillState: Equatable {
    var identifier: String
    var phoneNumber: String
  }

  static func loadPrefillState(defaults: UserDefaults = .standard) -> PrefillState {
    PrefillState(
      identifier: defaults.string(forKey: identifierKey) ?? "",
      phoneNumber: defaults.string(forKey: phoneNumberKey) ?? ""
    )
  }

  static func storeIdentifier(_ value: String, defaults: UserDefaults = .standard) {
    defaults.set(value, forKey: identifierKey)
  }

  static func storePhoneNumber(_ value: String, defaults: UserDefaults = .standard) {
    defaults.set(value, forKey: phoneNumberKey)
  }

  static func clearPrefillState(defaults: UserDefaults = .standard) {
    defaults.removeObject(forKey: identifierKey)
    defaults.removeObject(forKey: phoneNumberKey)
  }
}

#endif
