//
//  AuthConfig.swift
//  Clerk
//

#if os(iOS)

import ClerkKit

/// Configuration values applied to ``AuthView`` via its view modifiers.
struct AuthConfig: Equatable {
  /// The initial value for the identifier field (email, username, or phone number).
  var initialIdentifier: String?

  /// Whether identifier values are persisted between sessions.
  var persistsIdentifiers: Bool = true

  /// Unsafe metadata to attach to any sign-up created from this view.
  var unsafeMetadata: JSON?
}

#endif
