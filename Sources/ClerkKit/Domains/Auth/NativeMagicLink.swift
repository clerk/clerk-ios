//
//  NativeMagicLink.swift
//  Clerk
//

import CryptoKit
import Foundation
import Security

struct NativeMagicLinkCompleteParams: Encodable {
  let flowId: String
  let approvalToken: String
  let codeVerifier: String
  let attestation: String? = nil
}

struct NativeMagicLinkCompleteResponse: Codable, Equatable {
  let flowId: String?
  let ticket: String
}

struct PendingNativeMagicLinkFlow: Codable, Equatable {
  let codeVerifier: String
  let createdAt: Date
  let expiresAt: Date
}

struct NativeMagicLinkCallback: Equatable {
  let flowId: String
  let approvalToken: String

  init(url: URL) throws {
    guard let flowId = Self.queryParam(named: "flow_id", in: url) else {
      throw ClerkClientError(message: "Magic link callback is missing flow_id.")
    }

    guard let approvalToken = Self.queryParam(named: "approval_token", in: url) else {
      throw ClerkClientError(message: "Magic link callback is missing approval_token.")
    }

    self.flowId = flowId
    self.approvalToken = approvalToken
  }

  static func canHandle(_ url: URL) -> Bool {
    queryParam(named: "flow_id", in: url) != nil
      || queryParam(named: "approval_token", in: url) != nil
  }

  private static func queryParam(named name: String, in url: URL) -> String? {
    guard let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
      .queryItems?
      .first(where: { $0.name == name })?
      .value?
      .trimmingCharacters(in: .whitespacesAndNewlines),
      !value.isEmpty
    else {
      return nil
    }

    return value
  }
}

enum NativeMagicLinkPKCE {
  static let codeChallengeMethod = "S256"

  struct Pair: Equatable {
    let verifier: String
    let challenge: String
  }

  static func generatePair() throws -> Pair {
    var randomBytes = [UInt8](repeating: 0, count: 32)
    let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
    guard status == errSecSuccess else {
      throw ClerkClientError(message: "Unable to generate a secure magic link verifier.")
    }

    let verifier = Data(randomBytes).base64EncodedString().base64URLFromBase64String()
    let digest = SHA256.hash(data: Data(verifier.utf8))
    let challenge = Data(digest).base64EncodedString().base64URLFromBase64String()
    return Pair(verifier: verifier, challenge: challenge)
  }
}

@MainActor
enum NativeMagicLinkStore {
  private static let ttl: TimeInterval = 10 * 60

  private static var keychain: any KeychainStorage {
    Clerk.shared.dependencies.keychain
  }

  static func save(codeVerifier: String) throws {
    let createdAt = Date()
    let pendingFlow = PendingNativeMagicLinkFlow(
      codeVerifier: codeVerifier,
      createdAt: createdAt,
      expiresAt: createdAt.addingTimeInterval(ttl)
    )
    let data = try JSONEncoder.clerkEncoder.encode(pendingFlow)
    try keychain.set(data, forKey: ClerkKeychainKey.pendingNativeMagicLinkFlow.rawValue)
  }

  static func load() -> PendingNativeMagicLinkFlow? {
    guard let data = try? keychain.data(forKey: ClerkKeychainKey.pendingNativeMagicLinkFlow.rawValue) else {
      return nil
    }

    guard let pendingFlow = try? JSONDecoder.clerkDecoder.decode(PendingNativeMagicLinkFlow.self, from: data) else {
      clear()
      return nil
    }

    guard pendingFlow.expiresAt > Date() else {
      clear()
      return nil
    }

    return pendingFlow
  }

  static func clear() {
    try? keychain.deleteItem(forKey: ClerkKeychainKey.pendingNativeMagicLinkFlow.rawValue)
  }
}

let nativeMagicLinkTerminalErrorCodes: Set<String> = [
  "approval_token_consumed",
  "approval_token_expired",
  "approval_token_invalid",
  "pkce_verification_failed",
  "flow_not_approved",
]
