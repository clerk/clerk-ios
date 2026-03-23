//
//  AuthIdentifierConfig.swift
//  Clerk
//

#if os(iOS)

/// Configuration for identifier pre-filling and persistence on ``AuthView``.
struct AuthIdentifierConfig: Equatable {
  /// The initial value for the identifier field (email, username, or phone number).
  var initialIdentifier: String?

  /// Whether identifier values are persisted between sessions.
  var persistsIdentifiers: Bool = true
}

#endif
