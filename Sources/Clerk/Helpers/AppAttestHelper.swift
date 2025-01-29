//
//  AppAttestHelper.swift
//  Clerk
//
//  Created by Mike Pitre on 1/29/25.
//

import Foundation
import DeviceCheck
import CryptoKit
import SimpleKeychain

struct AppAttestHelper {
    
    enum AttestationError: Error {
        case unsupportedDevice
        case noChallengeProvided
        case unableToFormatChallengeAsData
    }
    
    /// Performs device attestation by generating an attestation object using a challenge from the server.
    @discardableResult
    static func performDeviceAttestation() async throws {
        guard DCAppAttestService.shared.isSupported else {
            throw AttestationError.unsupportedDevice
        }
        
        // Get the challenge from the server
        let request = ClerkFAPI.v1.client.deviceAttestation.challenges.post
        guard let challenge = try await Clerk.shared.apiClient.send(request).value["challenge"] else {
            throw AttestationError.noChallengeProvided
        }

        // Generate the app attest key
        let keyId = try await DCAppAttestService.shared.generateKey()
        
        // Create the client data hash
        guard let challengeData = challenge.data(using: .utf8) else {
            throw AttestationError.unableToFormatChallengeAsData
        }
        let clientDataHash = Data(SHA256.hash(data: challengeData))
        
        // Attest the new key
        let attestation = try await DCAppAttestService.shared.attestKey(keyId, clientDataHash: clientDataHash)
        
        // Verify with the server
        try await verify(keyId: keyId, challenge: challenge, attestation: attestation)
        
        // If verify succeeds, save the keyId to the keychain
        try SimpleKeychain().set(keyId, forKey: "AttestKeyId")
    }
    
    private static func verify(keyId: String, challenge: String, attestation: Data) async throws {
        let body = [
            "key_id": keyId,
            "challenge": challenge,
            "attestation": attestation.base64EncodedString(),
            "bundle_id": Bundle.main.bundleIdentifier
        ]
        
        let request = ClerkFAPI.v1.client.deviceAttestation.verify.post(body)
        try await Clerk.shared.apiClient.send(request)
    }
    
    static var hasKeyId: Bool {
        do {
            return try SimpleKeychain().hasItem(forKey: "AttestKeyId")
        } catch {
            return false
        }
    }
    
    static func removeKeyId() throws {
        try SimpleKeychain().deleteItem(forKey: "AttestKeyId")
    }
}
