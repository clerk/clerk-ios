//
//  PasskeyService.swift
//  Clerk
//
//  Created by Mike Pitre on 3/10/25.
//

import FactoryKit
import Foundation

struct PasskeyService {
  var create: @MainActor () async throws -> Passkey
  var update: @MainActor (_ passkey: Passkey, _ name: String) async throws -> Passkey
  var attemptVerification: @MainActor (_ passkey: Passkey, _ credential: String) async throws -> Passkey
  var delete: @MainActor (_ passkey: Passkey) async throws -> DeletedObject
}

extension PasskeyService {

  static var liveValue: Self {
    .init(
      create: {
        let request = ClerkFAPI.v1.me.passkeys.post(
          queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        return try await Container.shared.apiClient().send(request).value.response
      },
      update: { passkey, name in
        let request = ClerkFAPI.v1.me.passkeys.withId(passkey.id).patch(
          queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
          body: ["name": name]
        )
        return try await Container.shared.apiClient().send(request).value.response
      },
      attemptVerification: { passkey, credential in
        let request = ClerkFAPI.v1.me.passkeys.withId(passkey.id).attemptVerification.post(
          queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
          body: [
            "strategy": "passkey",
            "public_key_credential": credential,
          ]
        )
        return try await Container.shared.apiClient().send(request).value.response
      },
      delete: { passkey in
        let request = ClerkFAPI.v1.me.passkeys.withId(passkey.id).delete(
          queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        return try await Container.shared.apiClient().send(request).value.response
      }
    )
  }

}

extension Container {

  var passkeyService: Factory<PasskeyService> {
    self { .liveValue }
  }

}
