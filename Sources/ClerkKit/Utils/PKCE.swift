//
//  PKCE.swift
//  Clerk
//

import CryptoKit
import Foundation
import Security

/// Generates PKCE values using the `S256` code challenge method (RFC 7636).
enum PKCE {
  static let codeChallengeMethod = "S256"

  struct Pair: Equatable {
    let verifier: String
    let challenge: String
  }

  static func generatePair() throws -> Pair {
    let randomBytes = try SecureRandom.bytes(count: 32)
    let verifier = Data(randomBytes).base64EncodedString().base64URLFromBase64String()
    return Pair(verifier: verifier, challenge: challenge(for: verifier))
  }

  static func challenge(for verifier: String) -> String {
    let digest = SHA256.hash(data: Data(verifier.utf8))
    return Data(digest).base64EncodedString().base64URLFromBase64String()
  }
}

enum SecureRandom {
  static func bytes(count: Int) throws -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: count)
    guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
      throw ClerkClientError(message: "Unable to generate secure random data.")
    }
    return bytes
  }
}
