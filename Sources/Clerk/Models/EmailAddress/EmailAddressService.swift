//
//  EmailAddressService.swift
//  Clerk
//
//  Created by Mike Pitre on 2/26/25.
//

import FactoryKit
import Foundation

struct EmailAddressService {
  var prepareVerification: @MainActor (_ emailAddressId: String, _ strategy: EmailAddress.PrepareStrategy) async throws -> EmailAddress
  var attemptVerification: @MainActor (_ emailAddressId: String, _ strategy: EmailAddress.AttemptStrategy) async throws -> EmailAddress
  var destroy: @MainActor (_ emailAddressId: String) async throws -> DeletedObject
}

extension EmailAddressService {

  static var liveValue: Self {
    .init(
      prepareVerification: { id, strategy in
        let request = ClerkFAPI.v1.me.emailAddresses.id(id).prepareVerification.post(
          queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
          body: strategy.requestBody
        )
        return try await Container.shared.apiClient().send(request).value.response
      },
      attemptVerification: { id, strategy in
        let request = ClerkFAPI.v1.me.emailAddresses.id(id).attemptVerification.post(
          queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
          body: strategy.requestBody
        )
        return try await Container.shared.apiClient().send(request).value.response
      },
      destroy: { id in
        let request = ClerkFAPI.v1.me.emailAddresses.id(id).delete(
          queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        return try await Container.shared.apiClient().send(request).value.response
      }
    )
  }

}

extension Container {

  var emailAddressService: Factory<EmailAddressService> {
    self { .liveValue }
  }

}
