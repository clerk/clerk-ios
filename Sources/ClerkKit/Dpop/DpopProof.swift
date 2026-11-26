//
//  DpopProof.swift
//  Clerk
//

import CryptoKit
import Foundation

struct DpopBoundRequest: Equatable {
  let method: String
  let url: URL
  let accessToken: String?
}

enum DpopProof {
  static let headerName = "DPoP"

  static func build(key: any DeviceKey, request: DpopBoundRequest, now: Date, jti: String) throws -> String {
    let header: [String: Any] = [
      "typ": "dpop+jwt",
      "alg": "ES256",
      "jwk": key.publicJwk.members,
    ]
    var payload: [String: Any] = try [
      "jti": jti,
      "htm": request.method,
      "htu": htu(request.url),
      "iat": Int(now.timeIntervalSince1970.rounded(.down)),
      "clerk_sl": key.securityLevel.wireName,
    ]
    if let accessToken = request.accessToken {
      payload["ath"] = accessTokenHash(accessToken)
    }

    let signingInput = try "\(encodedJSON(header)).\(encodedJSON(payload))"
    let signature = try key.sign(Data(signingInput.utf8))
    return "\(signingInput).\(Es256.base64URLEncoded(signature))"
  }

  /// RFC 9449 §4.2 binds the proof to the target URI without its query and fragment.
  static func htu(_ url: URL) throws -> String {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
      throw DpopProofError.invalidURL
    }
    components.user = nil
    components.password = nil
    components.query = nil
    components.fragment = nil
    guard let target = components.url?.absoluteString else {
      throw DpopProofError.invalidURL
    }
    return target
  }

  static func accessTokenHash(_ accessToken: String) -> String {
    Es256.base64URLEncoded(Data(SHA256.hash(data: Data(accessToken.utf8))))
  }

  private static func encodedJSON(_ object: [String: Any]) throws -> String {
    try Es256.base64URLEncoded(
      JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
    )
  }
}

enum DpopProofError: Error, Equatable {
  case invalidURL
}
