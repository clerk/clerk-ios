//
//  EmailAddressAPI.swift
//  Clerk
//

import Foundation

package enum EmailAddressAPI {
  package static func create(email: String) -> Request<ClientResponse<EmailAddress>> {
    Request(
      path: "/v1/me/email_addresses",
      method: .post,
      scopedToActiveSession: true,
      body: ["email_address": email]
    )
  }

  package static func prepareVerification(emailAddressId: String, strategy: EmailAddress.PrepareStrategy) -> Request<ClientResponse<EmailAddress>> {
    Request(
      path: "/v1/me/email_addresses/\(emailAddressId)/prepare_verification",
      method: .post,
      scopedToActiveSession: true,
      body: strategy.requestBody
    )
  }

  package static func attemptVerification(emailAddressId: String, strategy: EmailAddress.AttemptStrategy) -> Request<ClientResponse<EmailAddress>> {
    Request(
      path: "/v1/me/email_addresses/\(emailAddressId)/attempt_verification",
      method: .post,
      scopedToActiveSession: true,
      body: strategy.requestBody
    )
  }

  package static func destroy(emailAddressId: String) -> Request<ClientResponse<DeletedObject>> {
    Request(
      path: "/v1/me/email_addresses/\(emailAddressId)",
      method: .delete,
      scopedToActiveSession: true
    )
  }
}
