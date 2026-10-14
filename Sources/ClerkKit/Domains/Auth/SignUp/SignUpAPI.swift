//
//  SignUpAPI.swift
//  Clerk
//

import Foundation

package enum SignUpAPI {
  static func create(params: SignUp.CreateParams) -> Request<ClientResponse<SignUp>> {
    Request(
      path: "/v1/client/sign_ups",
      method: .post,
      canEstablishClientWhenTokenless: true,
      body: params
    )
  }

  static func prepareVerification(signUpId: String, params: SignUp.PrepareVerificationParams) -> Request<ClientResponse<SignUp>> {
    Request(
      path: "/v1/client/sign_ups/\(signUpId)/prepare_verification",
      method: .post,
      body: params
    )
  }

  static func attemptVerification(signUpId: String, params: SignUp.AttemptVerificationParams) -> Request<ClientResponse<SignUp>> {
    Request(
      path: "/v1/client/sign_ups/\(signUpId)/attempt_verification",
      method: .post,
      body: params
    )
  }

  static func update(signUpId: String, params: SignUp.UpdateParams) -> Request<ClientResponse<SignUp>> {
    Request(
      path: "/v1/client/sign_ups/\(signUpId)",
      method: .patch,
      body: params
    )
  }

  static func get(signUpId: String, params: SignUp.GetParams) -> Request<ClientResponse<SignUp>> {
    var queryParams: [(String, String?)] = []
    if let rotatingTokenNonce = params.rotatingTokenNonce {
      queryParams.append(
        (
          "rotating_token_nonce",
          rotatingTokenNonce.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        )
      )
    }

    return Request(
      path: "/v1/client/sign_ups/\(signUpId)",
      method: .get,
      query: queryParams
    )
  }
}
