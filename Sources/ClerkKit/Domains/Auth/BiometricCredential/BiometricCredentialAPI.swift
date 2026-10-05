//
//  BiometricCredentialAPI.swift
//  Clerk
//

import Foundation

package enum BiometricCredentialAPI {
  package static func list() -> Request<ClientResponse<[BiometricCredential]>> {
    Request(
      path: "/v1/me/biometric_credentials",
      method: .get,
      scopedToActiveSession: true
    )
  }

  package static func prepareEnrollment(
    sessionId: String,
    params: BiometricCredential.PrepareEnrollmentParams
  ) -> Request<ClientResponse<BiometricCredentialChallenge>> {
    Request(
      path: "/v1/me/biometric_credentials/prepare",
      method: .post,
      query: [("_clerk_session_id", value: sessionId)],
      body: params
    )
  }

  package static func attemptEnrollment(
    sessionId: String,
    params: BiometricCredential.AttemptEnrollmentParams
  ) -> Request<ClientResponse<BiometricCredential>> {
    Request(
      path: "/v1/me/biometric_credentials/attempt",
      method: .post,
      query: [("_clerk_session_id", value: sessionId)],
      body: params
    )
  }

  package static func validateSignInCredential(biometricCredentialId: String) -> Request<ClientResponse<BiometricCredentialValidation>> {
    Request(
      path: "/v1/client/biometric_credentials/validate",
      method: .post,
      body: BiometricCredentialValidation.Params(biometricCredentialId: biometricCredentialId)
    )
  }

  package static func revoke(
    biometricCredentialId: String,
    sessionId: String?
  ) -> Request<ClientResponse<BiometricCredential>> {
    Request(
      path: "/v1/me/biometric_credentials/\(biometricCredentialId)",
      method: .delete,
      query: [("_clerk_session_id", value: sessionId)]
    )
  }
}
