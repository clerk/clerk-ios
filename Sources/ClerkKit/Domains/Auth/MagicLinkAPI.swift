//
//  MagicLinkAPI.swift
//  Clerk
//

import Foundation

enum MagicLinkAPI {
  static func complete(params: MagicLinkCompleteParams) -> Request<ClientResponse<MagicLinkCompleteResult>> {
    Request(
      path: "/v1/client/magic_links/complete",
      method: .post,
      canEstablishClientWhenTokenless: true,
      body: params
    )
  }
}
