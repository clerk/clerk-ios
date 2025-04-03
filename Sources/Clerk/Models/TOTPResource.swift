//
//  TOTPResource.swift
//
//
//  Created by Mike Pitre on 2/13/24.
//

import Foundation

/// Represents information about a TOTP configuration.
public struct TOTPResource: Codable, Hashable, Equatable, Sendable {

  /// A unique identifier for this TOTP secret.
  public let id: String

  /// The generated TOTP secret. Note: this is only returned to the client upon creation and cannot be retrieved afterwards.
  public let secret: String?

  /// A complete TOTP configuration URI including the Issuer, Account, etc that can be pasted to an authenticator app or encoded to a QR code and scanned for convenience. Just like the secret, the URI is exposed to the client only upon creation and cannot be retrieved afterwards.
  public let uri: String?

  /// Whether this TOTP secret has been verified by the user by providing one code generated with it. TOTP is not enabled on the user unless they have a verified secret.
  public let verified: Bool

  /// A set of fresh generated Backup codes. Note that this will be populated if the feature is enabled in your instance and the user doesn't already have backup codes generated.
  public let backupCodes: [String]?

  /// Creation date of the TOTP secret.
  public let createdAt: Date

  /// Update timestamp of the TOTP secret.
  public let updatedAt: Date

  public init(
    id: String,
    secret: String? = nil,
    uri: String? = nil,
    verified: Bool,
    backupCodes: [String]? = nil,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.secret = secret
    self.uri = uri
    self.verified = verified
    self.backupCodes = backupCodes
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

extension TOTPResource {

  static var mock: TOTPResource {
    .init(
      id: "1",
      secret: "1234567890",
      uri: "https://mock.com/totp",
      verified: true,
      backupCodes: ["123", "456"],
      createdAt: .distantPast,
      updatedAt: .distantPast
    )
  }

}
