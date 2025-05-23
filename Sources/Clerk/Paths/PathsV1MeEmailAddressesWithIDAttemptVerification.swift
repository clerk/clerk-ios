//
//  PathsV1MeEmailAddressesWithIDAttemptVerification.swift
//
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.MeEndpoint.EmailAddressesEndpoint.WithIdEndpoint {

  var attemptVerification: AttemptVerificationEndpoint {
    AttemptVerificationEndpoint(path: path + "/attempt_verification")
  }

  struct AttemptVerificationEndpoint {
    /// Path: `v1/me/email_addresses/{id}/attempt_verification`
    let path: String

    func post(queryItems: [URLQueryItem] = [], body: Encodable) -> Request<ClientResponse<EmailAddress>> {
      .init(path: path, method: .post, query: queryItems.asTuples, body: body)
    }
  }
}
