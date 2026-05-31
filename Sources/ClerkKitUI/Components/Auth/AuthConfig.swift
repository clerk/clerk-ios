//
//  AuthConfig.swift
//  Clerk
//

#if os(iOS)

import ClerkKit

/// Configuration values applied to an ``AuthView`` flow.
struct AuthConfig: Equatable {
  /// The initial value for the identifier field (email, username, or phone number).
  var initialIdentifier: String?

  /// Whether identifier values are persisted between sessions.
  var persistsIdentifiers: Bool = true

  /// Unsafe metadata to attach when this flow creates a sign-up.
  var unsafeMetadata: JSON?
}

#endif
