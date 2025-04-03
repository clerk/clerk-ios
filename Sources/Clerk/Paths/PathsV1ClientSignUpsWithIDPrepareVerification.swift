//
//  PathsV1ClientSignUpsWithIDPrepareVerification.swift
//
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.ClientEndpoint.SignUpsEndpoint.WithIdEndpoint {

  var prepareVerification: PrepareVerificationEndpoint {
    PrepareVerificationEndpoint(path: path + "/prepare_verification")
  }

  struct PrepareVerificationEndpoint {
    /// Path: `v1/client/sign_ups/{id}/prepare_verification`
    let path: String

    func post(_ params: SignUp.PrepareVerificationParams) -> Request<ClientResponse<SignUp>> {
      .init(path: path, method: .post, body: params)
    }
  }
}
