//
//  AuthConfig.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit

/// Configuration values applied to an ``AuthView`` flow.
struct AuthConfig: Equatable {
  /// The initial value for the identifier field (email, username, or phone number).
  var initialIdentifier: String?

  /// The initial value for the first name field during sign-up.
  var initialFirstName: String?

  /// The initial value for the last name field during sign-up.
  var initialLastName: String?

  /// Whether configured initial values should be shown as read-only fields.
  var prefilledFieldsAreLocked = false

  /// Whether identifier values are persisted between sessions.
  var persistsIdentifiers: Bool = true

  /// Unsafe metadata to attach when this flow creates a sign-up.
  var unsafeMetadata: JSON?

  /// Whether this flow should offer trusted-device sign-in when a local credential is available.
  var allowsTrustedDeviceSignIn = true
}

#endif
