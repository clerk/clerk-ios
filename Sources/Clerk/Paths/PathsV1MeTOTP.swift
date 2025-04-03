//
//  PathsV1MeTOTP.swift
//
//
//  Created by Mike Pitre on 2/13/24.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.MeEndpoint {

  var totp: TOTPEndpoint {
    TOTPEndpoint(path: path + "/totp")
  }

  struct TOTPEndpoint {
    /// Path: `v1/me/totp`
    let path: String

    func post(queryItems: [URLQueryItem] = []) -> Request<ClientResponse<TOTPResource>> {
      .init(path: path, method: .post, query: queryItems.asTuples)
    }

    func delete(queryItems: [URLQueryItem] = []) -> Request<ClientResponse<DeletedObject>> {
      .init(path: path, method: .delete, query: queryItems.asTuples)
    }
  }

}
