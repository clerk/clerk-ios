//
//  AuthIdentifierConfig.swift
//  Clerk
//

#if os(iOS)

/// Configuration for identifier pre-filling and persistence on ``AuthView``.
struct AuthIdentifierConfig: Equatable {
  /// The initial value for the email or username field.
  var initialIdentifier: String?

  /// The initial value for the phone number field.
  var initialPhoneNumber: String?

  /// Whether identifier values are persisted between sessions.
  var persistsIdentifiers: Bool = true
}

#endif
