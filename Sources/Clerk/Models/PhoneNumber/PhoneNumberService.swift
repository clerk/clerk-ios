//
//  PhoneNumberService.swift
//  Clerk
//
//  Created by Mike Pitre on 3/10/25.
//

import FactoryKit
import Foundation

struct PhoneNumberService {
  var delete: @MainActor (_ phoneNumber: PhoneNumber) async throws -> DeletedObject
  var prepareVerification: @MainActor (_ phoneNumber: PhoneNumber) async throws -> PhoneNumber
  var attemptVerification: @MainActor (_ phoneNumber: PhoneNumber, _ code: String) async throws -> PhoneNumber
  var makeDefaultSecondFactor: @MainActor (_ phoneNumber: PhoneNumber) async throws -> PhoneNumber
  var setReservedForSecondFactor: @MainActor (_ phoneNumber: PhoneNumber, _ reserved: Bool) async throws -> PhoneNumber
}

extension PhoneNumberService {

  static var liveValue: Self {
    .init(
      delete: { phoneNumber in
        let request = ClerkFAPI.v1.me.phoneNumbers.id(phoneNumber.id).delete(
          queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        return try await Container.shared.apiClient().send(request).value.response
      },
      prepareVerification: { phoneNumber in
        let request = ClerkFAPI.v1.me.phoneNumbers.id(phoneNumber.id).prepareVerification.post(
          queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        return try await Container.shared.apiClient().send(request).value.response
      },
      attemptVerification: { phoneNumber, code in
        let request = ClerkFAPI.v1.me.phoneNumbers.id(phoneNumber.id).attemptVerification.post(
          queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
          body: ["code": code]
        )
        return try await Container.shared.apiClient().send(request).value.response
      },
      makeDefaultSecondFactor: { phoneNumber in
        let request = ClerkFAPI.v1.me.phoneNumbers.id(phoneNumber.id).patch(
          queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
          body: ["default_second_factor": true]
        )
        return try await Container.shared.apiClient().send(request).value.response
      },
      setReservedForSecondFactor: { phoneNumber, reserved in
        let request = ClerkFAPI.v1.me.phoneNumbers.id(phoneNumber.id).patch(
          queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
          body: ["reserved_for_second_factor": reserved]
        )
        return try await Container.shared.apiClient().send(request).value.response
      }
    )
  }

}

extension Container {

  var phoneNumberService: Factory<PhoneNumberService> {
    self { .liveValue }
  }

}
