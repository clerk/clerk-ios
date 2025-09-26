//
//  Passkey.swift
//  Clerk
//
//  Created by Mike Pitre on 9/6/24.
//

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
        let request = Request<ClientResponse<Passkey>>.build(path: "/v1/me/passkeys") {
            $0.method(.post)
            $0.appendSessionIdQuery()
        }

        return try await Clerk.shared.dependencyContainer.apiClient.send(request).value.response
    }

    /// Updates the name of the associated passkey for the signed-in user.
    @discardableResult @MainActor
    public func update(name: String) async throws -> Passkey {
        let request = Request<ClientResponse<Passkey>>.build(path: "/v1/me/passkeys/\(id)") {
            $0.method(.patch)
            $0.appendSessionIdQuery()
            $0.body(["name": name])
        }

        return try await Clerk.shared.dependencyContainer.apiClient.send(request).value.response
    }

    /// Attempts to verify the passkey with a credential.
    @discardableResult @MainActor
    public func attemptVerification(credential: String) async throws -> Passkey {
        let request = Request<ClientResponse<Passkey>>.build(path: "/v1/me/passkeys/\(id)/attempt_verification") {
            $0.method(.post)
            $0.appendSessionIdQuery()
            $0.body([
                "strategy": "passkey",
                "public_key_credential": credential
            ])
        }

        return try await Clerk.shared.dependencyContainer.apiClient.send(request).value.response
    }

    /// Deletes the associated passkey for the signed-in user.
    @discardableResult @MainActor
    public func delete() async throws -> DeletedObject {
        let request = Request<ClientResponse<DeletedObject>>.build(path: "/v1/me/passkeys/\(id)") {
            $0.method(.delete)
            $0.appendSessionIdQuery()
        }

        return try await Clerk.shared.dependencyContainer.apiClient.send(request).value.response
    }

}

@_spi(Internal)
public extension Passkey {

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
