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

extension Passkey {

  /// Creates a new passkey
  @discardableResult @MainActor
  public static func create() async throws -> Passkey {
    try await Container.shared.apiClient().request()
      .add(path: "/v1/me/passkeys")
      .method(.post)
      .addClerkSessionId()
      .data(type: ClientResponse<Passkey>.self)
      .async()
      .response
  }

  /// Updates the name of the associated passkey for the signed-in user.
  @discardableResult @MainActor
  public func update(name: String) async throws -> Passkey {
    try await Container.shared.apiClient().request()
      .add(path: "/v1/me/passkeys/\(id)")
      .method(.patch)
      .addClerkSessionId()
      .body(fields: ["name": name])
      .data(type: ClientResponse<Passkey>.self)
      .async()
      .response
  }

  /// Attempts to verify the passkey with a credential.
  @discardableResult @MainActor
  public func attemptVerification(credential: String) async throws -> Passkey {
    try await Container.shared.apiClient().request()
      .add(path: "/v1/me/passkeys/\(id)/attempt_verification")
      .method(.post)
      .addClerkSessionId()
      .body(fields: [
        "strategy": "passkey",
        "public_key_credential": credential
      ])
      .data(type: ClientResponse<Passkey>.self)
      .async()
      .response
  }

  /// Deletes the associated passkey for the signed-in user.
  @discardableResult @MainActor
  public func delete() async throws -> DeletedObject {
    try await Container.shared.apiClient().request()
      .add(path: "/v1/me/passkeys/\(id)")
      .method(.delete)
      .addClerkSessionId()
      .body(fields: ["name": name])
      .data(type: ClientResponse<DeletedObject>.self)
      .async()
      .response
  }

}

extension Passkey {

  static var mock: Passkey {
    Passkey(
      id: "1",
      name: "iCloud Keychain",
      verification: .mockPasskeyVerifiedVerification,
      createdAt: Date(timeIntervalSinceReferenceDate: 1234567890),
      updatedAt: Date(timeIntervalSinceReferenceDate: 1234567890),
      lastUsedAt: Date(timeIntervalSinceReferenceDate: 1234567890)
    )
  }

}
