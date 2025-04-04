//
//  PathsV1ClientSignInsWithIDResetPassword.swift
//
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.ClientEndpoint.SignInsEndpoint.WithIdEndpoint {

  var resetPassword: ResetPasswordEndpoint {
    ResetPasswordEndpoint(path: path + "/reset_password")
  }

  struct ResetPasswordEndpoint {
    /// Path: `v1/client/sign_ins/{id}/reset_password`
    let path: String

    func post(_ params: any Encodable) -> Request<ClientResponse<SignIn>> {
      .init(path: path, method: .post, body: params)
    }
  }

}
