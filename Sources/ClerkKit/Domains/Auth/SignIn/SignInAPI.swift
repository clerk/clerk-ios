//
//  SignInAPI.swift
//  Clerk
//

import Foundation

package enum SignInAPI {
  static func create(params: SignIn.CreateParams) -> Request<ClientResponse<SignIn>> {
    Request(
      path: "/v1/client/sign_ins",
      method: .post,
      canEstablishClientWhenTokenless: true,
      body: params
    )
  }

  static func prepareFirstFactor(signInId: String, params: SignIn.PrepareFirstFactorParams) -> Request<ClientResponse<SignIn>> {
    Request(
      path: "/v1/client/sign_ins/\(signInId)/prepare_first_factor",
      method: .post,
      body: params
    )
  }

  static func attemptFirstFactor(signInId: String, params: SignIn.AttemptFirstFactorParams) -> Request<ClientResponse<SignIn>> {
    Request(
      path: "/v1/client/sign_ins/\(signInId)/attempt_first_factor",
      method: .post,
      body: params
    )
  }

  static func prepareSecondFactor(signInId: String, params: SignIn.PrepareSecondFactorParams) -> Request<ClientResponse<SignIn>> {
    Request(
      path: "/v1/client/sign_ins/\(signInId)/prepare_second_factor",
      method: .post,
      body: params
    )
  }

  static func attemptSecondFactor(signInId: String, params: SignIn.AttemptSecondFactorParams) -> Request<ClientResponse<SignIn>> {
    Request(
      path: "/v1/client/sign_ins/\(signInId)/attempt_second_factor",
      method: .post,
      body: params
    )
  }

  static func resetPassword(signInId: String, params: SignIn.ResetPasswordParams) -> Request<ClientResponse<SignIn>> {
    Request(
      path: "/v1/client/sign_ins/\(signInId)/reset_password",
      method: .post,
      body: params
    )
  }

  static func get(signInId: String, params: SignIn.GetParams) -> Request<ClientResponse<SignIn>> {
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
      path: "/v1/client/sign_ins/\(signInId)",
      method: .get,
      query: queryParams
    )
  }
}
