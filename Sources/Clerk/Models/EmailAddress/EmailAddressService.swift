//
//  EmailAddressService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import FactoryKit
import Foundation

extension Container {
  
  var emailAddressService: Factory<EmailAddressService> {
    self { @MainActor in EmailAddressService() }
  }
  
}

@MainActor
struct EmailAddressService {
  
  var create: (_ email: String) async throws -> EmailAddress = { email in
    try await Container.shared.apiClient().request()
      .add(path: "v1/me/email_addresses")
      .addClerkSessionId()
      .method(.post)
      .body(formEncode: ["email_address": email])
      .data(type: ClientResponse<EmailAddress>.self)
      .async()
      .response
  }
  
  var prepareVerification: (_ emailAddressId: String, _ strategy: EmailAddress.PrepareStrategy) async throws -> EmailAddress = { emailAddressId, strategy in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/me/email_addresses/\(emailAddressId)/prepare_verification")
      .addClerkSessionId()
      .method(.post)
      .body(formEncode: strategy.requestBody)
      .data(type: ClientResponse<EmailAddress>.self)
      .async()
      .response
  }
  
  var attemptVerification: (_ emailAddressId: String, _ strategy: EmailAddress.AttemptStrategy) async throws -> EmailAddress = { emailAddressId, strategy in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/me/email_addresses/\(emailAddressId)/attempt_verification")
      .addClerkSessionId()
      .method(.post)
      .body(formEncode: strategy.requestBody)
      .data(type: ClientResponse<EmailAddress>.self)
      .async()
      .response
  }
  
  var destroy: (_ emailAddressId: String) async throws -> DeletedObject = { emailAddressId in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/me/email_addresses/\(emailAddressId)")
      .addClerkSessionId()
      .method(.delete)
      .data(type: ClientResponse<DeletedObject>.self)
      .async()
      .response
  }
  
} 