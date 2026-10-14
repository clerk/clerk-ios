//
//  TokenResource.swift
//

import Foundation

/// Represents information about a token.
///
/// The `TokenResource` structure encapsulates a token, such as a JWT.
public struct TokenResource: Codable, Equatable, Sendable {
  /// The jwt represented as a `String`.
  public var jwt: String

  public init(jwt: String) {
    self.jwt = jwt
  }
}

extension TokenResource {
  var decodedJWT: DecodedJWT? {
    do {
      return try DecodedJWT(jwt: jwt)
    } catch {
      ClerkLogger.error("Failed to decode JWT", error: error)
      return nil
    }
  }

  var featuresClaim: String {
    decodedJWT?.claim(name: "fea").string ?? ""
  }

  var plansClaim: String {
    decodedJWT?.claim(name: "pla").string ?? ""
  }

  var factorVerificationAgeClaim: [Int]? {
    guard let raw = decodedJWT?.body["fva"] else {
      return nil
    }
    if let values = raw as? [Int], values.count == 2 {
      return values
    }
    if let values = raw as? [NSNumber], values.count == 2 {
      return values.map(\.intValue)
    }
    return nil
  }
}
