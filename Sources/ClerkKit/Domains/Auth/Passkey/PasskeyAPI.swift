//
//  PasskeyAPI.swift
//  Clerk
//

import Foundation

package enum PasskeyAPI {
  package static func create() -> Request<ClientResponse<Passkey>> {
    Request(
      path: "/v1/me/passkeys",
      method: .post,
      scopedToActiveSession: true
    )
  }

  package static func update(passkeyId: String, name: String) -> Request<ClientResponse<Passkey>> {
    Request(
      path: "/v1/me/passkeys/\(passkeyId)",
      method: .patch,
      scopedToActiveSession: true,
      body: ["name": name]
    )
  }

  package static func attemptVerification(passkeyId: String, credential: String) -> Request<ClientResponse<Passkey>> {
    Request(
      path: "/v1/me/passkeys/\(passkeyId)/attempt_verification",
      method: .post,
      scopedToActiveSession: true,
      body: [
        "strategy": "passkey",
        "public_key_credential": credential,
      ]
    )
  }

  package static func delete(passkeyId: String) -> Request<ClientResponse<DeletedObject>> {
    Request(
      path: "/v1/me/passkeys/\(passkeyId)",
      method: .delete,
      scopedToActiveSession: true
    )
  }
}
