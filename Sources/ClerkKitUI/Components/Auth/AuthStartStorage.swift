//
//  AuthStartStorage.swift
//  Clerk
//

#if os(iOS)

import Foundation

/// Centralizes read/write/clear operations for the auth start prefill state
/// stored in `UserDefaults`.
///
/// Three keys are managed:
/// - `authStartIdentifier`: Email or username value.
/// - `authStartPhoneNumber`: Phone number value.
/// - `clerk_last_used_identifier_type`: Identifier type for badge display.
enum AuthStartStorage {
  private static let identifierKey = "authStartIdentifier"
  private static let phoneNumberKey = "authStartPhoneNumber"
  private static let identifierTypeKey = "clerk_last_used_identifier_type"

  struct PrefillState: Equatable {
    var identifier: String
    var phoneNumber: String
    var identifierType: String?
  }

  static func loadPrefillState(defaults: UserDefaults = .standard) -> PrefillState {
    PrefillState(
      identifier: defaults.string(forKey: identifierKey) ?? "",
      phoneNumber: defaults.string(forKey: phoneNumberKey) ?? "",
      identifierType: defaults.string(forKey: identifierTypeKey)
    )
  }

  static func storeIdentifier(_ value: String, defaults: UserDefaults = .standard) {
    defaults.set(value, forKey: identifierKey)
  }

  static func storePhoneNumber(_ value: String, defaults: UserDefaults = .standard) {
    defaults.set(value, forKey: phoneNumberKey)
  }

  static func storeIdentifierType(_ value: String?, defaults: UserDefaults = .standard) {
    if let value {
      defaults.set(value, forKey: identifierTypeKey)
    } else {
      defaults.removeObject(forKey: identifierTypeKey)
    }
  }

  static func clearPrefillState(defaults: UserDefaults = .standard) {
    defaults.removeObject(forKey: identifierKey)
    defaults.removeObject(forKey: phoneNumberKey)
    defaults.removeObject(forKey: identifierTypeKey)
  }
}

#endif
