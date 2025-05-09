//
//  PathsV1ClientSignInsWithID.swift
//
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.ClientEndpoint.SignInsEndpoint {

  func id(_ id: String) -> WithIdEndpoint {
    WithIdEndpoint(path: path + "/\(id)")
  }

  struct WithIdEndpoint {
    /// Path: `/v1/client/sign_ins/{id}`
    let path: String

    func get(rotatingTokenNonce: String? = nil) -> Request<ClientResponse<SignIn>> {
      if let rotatingTokenNonce {
        let queryEncodedNonce = rotatingTokenNonce.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        return .init(path: path, query: [("rotating_token_nonce", queryEncodedNonce)])
      } else {
        return .init(path: path)
      }
    }
  }

}
