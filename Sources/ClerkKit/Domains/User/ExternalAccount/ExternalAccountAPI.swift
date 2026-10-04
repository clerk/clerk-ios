//
//  ExternalAccountAPI.swift
//  Clerk
//

import Foundation

package enum ExternalAccountAPI {
  package static func reauthorize(
    externalAccountId: String,
    redirectUrl: String,
    additionalScopes: [String],
    oidcPrompts: [OIDCPrompt]
  ) -> Request<ClientResponse<ExternalAccount>> {
    var bodyParams: [String: JSON] = [
      "redirect_url": .string(redirectUrl),
    ]

    if !additionalScopes.isEmpty {
      bodyParams["additional_scope"] = .array(additionalScopes.map { .string($0) })
    }

    if let serializedPrompt = oidcPrompts.serializedPrompt {
      bodyParams["oidc_prompt"] = .string(serializedPrompt)
    }

    return Request(
      path: "/v1/me/external_accounts/\(externalAccountId)/reauthorize",
      method: .patch,
      scopedToActiveSession: true,
      body: bodyParams
    )
  }

  package static func destroy(externalAccountId: String) -> Request<ClientResponse<DeletedObject>> {
    Request(
      path: "/v1/me/external_accounts/\(externalAccountId)",
      method: .delete,
      scopedToActiveSession: true
    )
  }
}
