//
//  PathsV1ClientSessionsWithIDTokens.swift
//
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.ClientEndpoint.SessionsEndpoint.WithIdEndpoint {

  var tokens: TokensEndpoint {
    TokensEndpoint(path: path + "/tokens")
  }

  struct TokensEndpoint {
    /// Path: `v1/client/sessions/{id}/tokens`
    let path: String

    func post() -> Request<TokenResource?> {
      .init(path: path, method: .post)
    }
  }
}
