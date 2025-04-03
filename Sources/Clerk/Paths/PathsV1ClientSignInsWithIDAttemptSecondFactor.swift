//
//  PathsV1ClientSignInsWithIDAttemptSecondFactor.swift
//
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.ClientEndpoint.SignInsEndpoint.WithIdEndpoint {

  var attemptSecondFactor: AttemptSecondFactorEndpoint {
    AttemptSecondFactorEndpoint(path: path + "/attempt_second_factor")
  }

  struct AttemptSecondFactorEndpoint {
    /// Path: `v1/client/sign_ins/{id}/attempt_second_factor`
    let path: String

    func post(_ params: SignIn.AttemptSecondFactorParams) -> Request<ClientResponse<SignIn>> {
      .init(path: path, method: .post, body: params)
    }
  }

}
