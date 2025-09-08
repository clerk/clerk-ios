//
//  Passkey.swift
//  Clerk
//
//  Created by Mike Pitre on 9/6/24.
//

import FactoryKit
import Foundation

/// An object that represents a passkey associated with a user.
public struct Passkey: Codable, Identifiable, Equatable, Sendable, Hashable {
  /// The unique identifier of the passkey.
  public let id: String

  /// The passkey's name.
  public let name: String

  /// The verification details for the passkey.
  public let verification: Verification?

  /// The date when the passkey was created.
  public let createdAt: Date

  /// The date when the passkey was last updated.
  public let updatedAt: Date

  /// The date when the passkey was last used.
  public let lastUsedAt: Date?

  public init(
    id: String,
    name: String,
    verification: Verification? = nil,
    createdAt: Date,
    updatedAt: Date,
    lastUsedAt: Date? = nil
  ) {
    self.id = id
    self.name = name
    self.verification = verification
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.lastUsedAt = lastUsedAt
  }
}

extension Passkey {
  // MARK: - Private Properties

  var nonceJSON: JSON? {
    verification?.nonce?.toJSON()
  }

  var challenge: Data? {
    let challengeString = nonceJSON?.challenge?.stringValue
    return challengeString?.dataFromBase64URL()
  }

  var username: String? {
    nonceJSON?.user?.name?.stringValue
  }

  var userId: Data? {
    nonceJSON?.user?.id?.stringValue?.base64URLFromBase64String().dataFromBase64URL()
  }
}

public extension Passkey {
  /// Creates a new passkey
  @discardableResult @MainActor
  static func create() async throws -> Passkey {
    try await Container.shared.passkeyService().create()
  }

  /// Updates the name of the associated passkey for the signed-in user.
  @discardableResult @MainActor
  func update(name: String) async throws -> Passkey {
    try await Container.shared.passkeyService().update(id, name)
  }

  /// Attempts to verify the passkey with a credential.
  @discardableResult @MainActor
  func attemptVerification(credential: String) async throws -> Passkey {
    try await Container.shared.passkeyService().attemptVerification(id, credential)
  }

  /// Deletes the associated passkey for the signed-in user.
  @discardableResult @MainActor
  func delete() async throws -> DeletedObject {
    try await Container.shared.passkeyService().delete(id)
  }
}

extension Passkey {
  static var mock: Passkey {
    Passkey(
      id: "1",
      name: "iCloud Keychain",
      verification: .mockPasskeyVerifiedVerification,
      createdAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      updatedAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      lastUsedAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890)
    )
  }
}
