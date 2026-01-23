//
//  LastUsedIdentifierStorage.swift
//  Clerk
//

#if os(iOS)

import Foundation

/// Stores the last used identifier type locally to disambiguate when the backend returns "password".
///
/// The backend's `lastAuthenticationStrategy` returns "password" for all password-based sign-ins,
/// regardless of whether the user signed in with email, phone, or username. This storage tracks
/// which identifier type was actually used, serving as a fallback for that case.
enum LastUsedIdentifierStorage {
  private static let key = "clerk_last_used_identifier_type"

  /// The identifier types that can be stored.
  enum IdentifierType: String {
    case email
    case phone
    case username
  }

  /// Stores the identifier type used for the current sign-in attempt.
  ///
  /// Call this when the user submits an identifier before password authentication.
  static func store(_ type: IdentifierType) {
    UserDefaults.standard.set(type.rawValue, forKey: key)
  }

  /// Retrieves the last stored identifier type, if any.
  static func retrieve() -> IdentifierType? {
    guard let rawValue = UserDefaults.standard.string(forKey: key) else {
      return nil
    }
    return IdentifierType(rawValue: rawValue)
  }

  /// Clears the stored identifier type.
  static func clear() {
    UserDefaults.standard.removeObject(forKey: key)
  }
}

extension LastUsedIdentifierStorage.IdentifierType {
  func matches(_ strategies: [FactorStrategy]) -> Bool {
    switch self {
    case .email: strategies.contains(.emailCode)
    case .phone: strategies.contains(.phoneCode)
    case .username:
      strategies.contains(.password)
        && Set(strategies).isDisjoint(with: [.emailCode, .phoneCode])
    }
  }
}

#endif
