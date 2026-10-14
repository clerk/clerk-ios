//
//  HostedAuthAPI.swift
//  Clerk
//

import Foundation

enum HostedAuthAPI {
  static func create(params: HostedAuthCreateParams) -> Request<ClientResponse<HostedAuthResource>> {
    Request(
      path: "/v1/client/hosted_auth",
      method: .post,
      body: params,
      automaticallySyncClient: false,
      logBodies: false
    )
  }

  static func redeem(params: HostedAuthRedeemParams) -> Request<ClientResponse<Client?>> {
    Request(
      path: "/v1/client",
      method: .post,
      headers: [
        ClerkHeaderRequestMiddleware.canonicalClientRequestHeader: "1",
      ],
      body: params,
      automaticallySyncClient: false,
      logBodies: false
    )
  }
}
