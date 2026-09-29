//
//  AuthConfig.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit

struct AuthConfig: Equatable {
  var initialIdentifier: String?

  var initialFirstName: String?

  var initialLastName: String?

  var prefilledFieldsAreLocked = false

  var persistsIdentifiers: Bool = true

  var unsafeMetadata: JSON?
}

#endif
