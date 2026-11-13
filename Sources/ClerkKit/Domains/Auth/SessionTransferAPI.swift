//
//  SessionTransferAPI.swift
//  Clerk
//

import Foundation

enum SessionTransferAPI {
  static func create(sessionId: String, params: SessionTransferCreateParams) -> Request<ClientResponse<SessionTransferResource>> {
    Request(
      path: "/v1/client/sessions/\(sessionId)/session_transfers",
      method: .post,
      body: params,
      logBodies: false
    )
  }
}
