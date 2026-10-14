//
//  ClientAPI.swift
//  Clerk
//

import Foundation

package enum ClientAPI {
  /// Fetches the client.
  ///
  /// - Parameter skipClientId: When `true`, asks the header middleware to omit
  ///   `x-clerk-client-id` while still sending the stored device token, so the
  ///   backend resolves the client from a token that may have just changed.
  package static func get(skipClientId: Bool = false) -> Request<ClientResponse<Client?>> {
    Request(
      path: "/v1/client",
      headers: [
        ClerkHeaderRequestMiddleware.canonicalClientRequestHeader: "1",
        ClerkHeaderRequestMiddleware.skipClientIdHeader: skipClientId ? "1" : "0",
      ]
    )
  }
}
