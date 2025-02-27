//
//  AppAttestHelper.swift
//  Clerk
//
//  Created by Mike Pitre on 1/29/25.
//

import CryptoKit
import DeviceCheck
import Factory
import Foundation
import SimpleKeychain

/// A helper struct for handling Apple's DeviceCheck App Attest API.
struct AppAttestHelper {
    
    /// The key used to store the attestation key ID in the keychain.
    private static let keychainKey = "AttestKeyId"
    
    /// Errors that can occur during the attestation process.
    enum AttestationError: Error {
        case unsupportedDevice
        case unableToGetChallengeFromServer
        case unableToFormatChallengeAsData
    }
        
    /// Retrieves a challenge from the server for attestation.
    /// - Returns: A challenge string received from the server.
    /// - Throws: `AttestationError.unableToGetChallengeFromServer` if the challenge cannot be retrieved.
    private static func getChallenge() async throws -> String {
        let request = ClerkFAPI.v1.client.deviceAttestation.challenges.post
        guard let challenge = try await Container.shared.apiClient().send(request).value["challenge"] else {
            throw AttestationError.unableToGetChallengeFromServer
        }
        return challenge
    }
    
    /// Performs device attestation using Apple's DeviceCheck framework.
    /// - Returns: The generated key ID.
    /// - Throws: An error if attestation fails.
    @discardableResult
    static func performDeviceAttestation() async throws -> String {
        guard DCAppAttestService.shared.isSupported else {
            throw AttestationError.unsupportedDevice
        }
        
        let challenge = try await getChallenge()
        let keyId = try await DCAppAttestService.shared.generateKey()
        
        guard let challengeData = challenge.data(using: .utf8) else {
            throw AttestationError.unableToFormatChallengeAsData
        }
        
        let clientDataHash = Data(SHA256.hash(data: challengeData))
        let attestation = try await DCAppAttestService.shared.attestKey(keyId, clientDataHash: clientDataHash)
        try await verify(keyId: keyId, challenge: challenge, attestation: attestation)
        
        try SimpleKeychain().set(keyId, forKey: keychainKey)
        return keyId
    }
    
    /// Verifies the attestation key with the server.
    /// - Parameters:
    ///   - keyId: The key ID generated during attestation.
    ///   - challenge: The challenge string used for attestation.
    ///   - attestation: The attestation data.
    /// - Throws: An error if verification fails.
    private static func verify(keyId: String, challenge: String, attestation: Data) async throws {
        let body = [
            "key_id": keyId,
            "challenge": challenge,
            "attestation": attestation.base64EncodedString(),
            "bundle_id": Bundle.main.bundleIdentifier
        ]
        
        let request = ClerkFAPI.v1.client.deviceAttestation.verify.post(body)
        try await Container.shared.apiClient().send(request)
    }
    
    /// Creates an assertion using the attestation key.
    /// - Parameter payload: The data payload to be signed.
    /// - Returns: A base64-encoded assertion string.
    /// - Throws: An error if assertion generation fails.
    private static func createAssertion(payload: Data) async throws -> String {
        let keyId: String
        if let existingKeyId = Self.keyId {
            keyId = existingKeyId
        } else {
            keyId = try await performDeviceAttestation()
        }
        
        let hash = Data(SHA256.hash(data: payload))
        let assertion = try await DCAppAttestService.shared.generateAssertion(keyId, clientDataHash: hash)
        return assertion.base64EncodedString()
    }
    
    /// Performs assertion verification with the server.
    /// - Throws: An error if the assertion verification fails.
    static func performAssertion() async throws {
        guard DCAppAttestService.shared.isSupported else {
            throw AttestationError.unsupportedDevice
        }
        
        let challenge = try await getChallenge()
        let clientId = try clientId
        let payload = try JSONEncoder().encode(["client_id": clientId, "challenge": challenge])
        let assertion = try await createAssertion(payload: payload)
        
        let body = [
            "client_data": String(decoding: payload, as: UTF8.self),
            "assertion": assertion,
            "challenge": challenge,
            "platform": "ios",
            "bundle_id": Bundle.main.bundleIdentifier
        ]
        
        let request = ClerkFAPI.v1.client.verify.post(body)
        try await Container.shared.apiClient().send(request)
    }
    
    /// Checks whether a key ID is stored in the keychain.
    static var hasKeyId: Bool {
        do {
            return try SimpleKeychain().hasItem(forKey: keychainKey)
        } catch {
            return false
        }
    }
    
    /// Retrieves the stored attestation key ID from the keychain.
    private static var keyId: String? {
        try? SimpleKeychain().string(forKey: keychainKey)
    }
    
    /// Removes the stored attestation key ID from the keychain.
    /// - Throws: An error if key deletion fails.
    static func removeKeyId() throws {
        try SimpleKeychain().deleteItem(forKey: keychainKey)
    }
    
    /// Retrieves the stored attestation client ID from the keychain.
    ///
    /// This needs to come from the keychain, because if the initial client request is blocked on app load,
    /// the app wont have a client yet
    static var clientId: String {
        get throws {
            try SimpleKeychain().string(forKey: "clientId")
        }
    }
}
