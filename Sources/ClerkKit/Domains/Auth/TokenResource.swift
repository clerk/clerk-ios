//
//  TokenResource.swift
//
//
//  Created by Mike Pitre on 12/13/23.
//

import Foundation

/// Represents information about a token.
///
/// The `TokenResource` structure encapsulates a token, such as a JWT.
public struct TokenResource: Codable, Equatable, Sendable {

  /// The jwt represented as a `String`.
  public let jwt: String

  public init(jwt: String) {
    self.jwt = jwt
  }
}

extension TokenResource {
  /// Attempts to decode the JWT into a `DecodedJWT` object.
  ///
  /// - Returns: A `DecodedJWT` object if decoding is successful; otherwise `nil`.
  var decodedJWT: DecodedJWT? {
    do {
      return try DecodedJWT(jwt: jwt)
    } catch {
      ClerkLogger.error("Failed to decode JWT", error: error)
      return nil
    }
  }
}

extension TokenResource {

  package static var mock: TokenResource {
    .init(jwt: "jwt")
  }

}
