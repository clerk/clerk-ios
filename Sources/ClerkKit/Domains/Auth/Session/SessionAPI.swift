//
//  SessionAPI.swift
//  Clerk
//

import Foundation

package struct SessionTokenRequestParams: Encodable, Equatable {
  package var organizationId: String
  package var token: String?
  package var forceOrigin: String?

  package init(
    organizationId: String,
    token: String? = nil,
    forceOrigin: String? = nil
  ) {
    self.organizationId = organizationId
    self.token = token
    self.forceOrigin = forceOrigin
  }
}

package enum SessionAPI {
  package static func revoke(sessionId: String) -> Request<ClientResponse<Session>> {
    Request(
      path: "/v1/me/sessions/\(sessionId)/revoke",
      method: .post,
      scopedToActiveSession: true
    )
  }

  static func remove(sessionId: String) -> Request<EmptyResponse> {
    Request(
      path: "/v1/client/sessions/\(sessionId)/remove",
      method: .post
    )
  }

  static func removeAll() -> Request<EmptyResponse> {
    Request(
      path: "/v1/client/sessions",
      method: .delete
    )
  }

  package static func touch(sessionId: String, organizationId: String?) -> Request<ClientResponse<Session>> {
    Request(
      path: "/v1/client/sessions/\(sessionId)/touch",
      method: .post,
      body: [
        "active_organization_id": organizationId ?? "",
        "intent": "select_org",
      ],
      automaticallySyncClient: false
    )
  }

  package static func fetchToken(
    sessionId: String,
    template: String?,
    params: SessionTokenRequestParams?
  ) -> Request<TokenResource?> {
    let path = if let template {
      "/v1/client/sessions/\(sessionId)/tokens/\(template)"
    } else {
      "/v1/client/sessions/\(sessionId)/tokens"
    }
    let body = template == nil ? params : nil

    return Request(
      path: path,
      method: .post,
      body: body,
      logBodies: false
    )
  }

  static func startVerification(
    sessionId: String,
    params: Session.StartVerificationParams
  ) -> Request<ClientResponse<SessionVerification>> {
    Request(
      path: "/v1/client/sessions/\(sessionId)/verify",
      method: .post,
      body: params
    )
  }

  static func prepareFirstFactorVerification(
    sessionId: String,
    params: Session.PrepareFirstFactorVerificationParams
  ) -> Request<ClientResponse<SessionVerification>> {
    Request(
      path: "/v1/client/sessions/\(sessionId)/verify/prepare_first_factor",
      method: .post,
      body: params
    )
  }

  static func attemptFirstFactorVerification(
    sessionId: String,
    params: Session.AttemptFirstFactorVerificationParams
  ) -> Request<ClientResponse<SessionVerification>> {
    Request(
      path: "/v1/client/sessions/\(sessionId)/verify/attempt_first_factor",
      method: .post,
      body: params
    )
  }

  static func prepareSecondFactorVerification(
    sessionId: String,
    params: Session.PrepareSecondFactorVerificationParams
  ) -> Request<ClientResponse<SessionVerification>> {
    Request(
      path: "/v1/client/sessions/\(sessionId)/verify/prepare_second_factor",
      method: .post,
      body: params
    )
  }

  static func attemptSecondFactorVerification(
    sessionId: String,
    params: Session.AttemptSecondFactorVerificationParams
  ) -> Request<ClientResponse<SessionVerification>> {
    Request(
      path: "/v1/client/sessions/\(sessionId)/verify/attempt_second_factor",
      method: .post,
      body: params
    )
  }
}
