//
//  MagicLink.swift
//  Clerk
//

import CryptoKit
import Foundation
import Security

struct MagicLinkCompleteParams: Encodable {
  let flowId: String
  let approvalToken: String
  let codeVerifier: String
  let attestation: String? = nil
}

struct MagicLinkCompleteResponse: Codable, Equatable {
  let flowId: String?
  let ticket: String
}

struct PendingMagicLinkFlow: Codable, Equatable {
  enum Kind: String, Codable, Equatable {
    case signIn
    case signUp
  }

  let kind: Kind
  let codeVerifier: String
  let createdAt: Date
  let expiresAt: Date

  private enum CodingKeys: String, CodingKey {
    case kind
    case codeVerifier
    case createdAt
    case expiresAt
  }

  init(kind: Kind, codeVerifier: String, createdAt: Date, expiresAt: Date) {
    self.kind = kind
    self.codeVerifier = codeVerifier
    self.createdAt = createdAt
    self.expiresAt = expiresAt
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    kind = try container.decodeIfPresent(Kind.self, forKey: .kind) ?? .signIn
    codeVerifier = try container.decode(String.self, forKey: .codeVerifier)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    expiresAt = try container.decode(Date.self, forKey: .expiresAt)
  }
}

struct MagicLinkCallback: Equatable {
  let flowId: String
  let approvalToken: String

  init(url: URL) throws {
    guard let flowId = url.queryParam(named: Param.flowId.rawValue) else {
      throw ClerkClientError(message: "Magic link callback is missing flow_id.")
    }
    guard let approvalToken = url.queryParam(named: Param.approvalToken.rawValue) else {
      throw ClerkClientError(message: "Magic link callback is missing approval_token.")
    }

    self.flowId = flowId
    self.approvalToken = approvalToken
  }

  private enum Param: String, CaseIterable {
    case flowId = "flow_id"
    case approvalToken = "approval_token"
  }

  static let requiredParams = Set(Param.allCases.map(\.rawValue))
}

enum MagicLinkPKCE {
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

final class MagicLinkStore {
  private let keychain: any KeychainStorage
  private let ttl: TimeInterval = 10 * 60

  init(keychain: any KeychainStorage) {
    self.keychain = keychain
  }

  /// Stores the verifier for the active native magic-link flow.
  ///
  /// Only one pending flow is persisted at a time. Saving a new verifier
  /// replaces any previously stored pending flow.
  func save(kind: PendingMagicLinkFlow.Kind, codeVerifier: String) throws {
    let createdAt = Date()
    let pendingFlow = PendingMagicLinkFlow(
      kind: kind,
      codeVerifier: codeVerifier,
      createdAt: createdAt,
      expiresAt: createdAt.addingTimeInterval(ttl)
    )
    let data = try JSONEncoder.clerkEncoder.encode(pendingFlow)
    try keychain.set(data, forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue)
  }

  func load() -> PendingMagicLinkFlow? {
    guard let data = try? keychain.data(forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue) else {
      return nil
    }

    guard let pendingFlow = try? JSONDecoder.clerkDecoder.decode(PendingMagicLinkFlow.self, from: data) else {
      clear()
      return nil
    }

    guard pendingFlow.expiresAt > Date() else {
      clear()
      return nil
    }

    return pendingFlow
  }

  func clear() {
    try? keychain.deleteItem(forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue)
  }
}
