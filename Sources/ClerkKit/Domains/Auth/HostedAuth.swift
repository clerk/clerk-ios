//
//  HostedAuth.swift
//  Clerk
//

import Foundation

/// The Account Portal screen shown when hosted authentication starts.
public enum HostedAuthMode: String, Codable, Sendable {
  /// Opens Account Portal on sign-in.
  case signIn = "sign-in"

  /// Opens Account Portal on sign-up.
  case signUp = "sign-up"
}
