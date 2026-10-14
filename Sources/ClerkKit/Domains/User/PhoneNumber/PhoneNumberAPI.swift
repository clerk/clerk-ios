//
//  PhoneNumberAPI.swift
//  Clerk
//

import Foundation

package enum PhoneNumberAPI {
  package static func create(phoneNumber: String) -> Request<ClientResponse<PhoneNumber>> {
    Request(
      path: "/v1/me/phone_numbers",
      method: .post,
      scopedToActiveSession: true,
      body: ["phone_number": phoneNumber]
    )
  }

  package static func delete(phoneNumberId: String) -> Request<ClientResponse<DeletedObject>> {
    Request(
      path: "/v1/me/phone_numbers/\(phoneNumberId)",
      method: .delete,
      scopedToActiveSession: true
    )
  }

  package static func prepareVerification(phoneNumberId: String) -> Request<ClientResponse<PhoneNumber>> {
    Request(
      path: "/v1/me/phone_numbers/\(phoneNumberId)/prepare_verification",
      method: .post,
      scopedToActiveSession: true,
      body: ["strategy": "phone_code"]
    )
  }

  package static func attemptVerification(phoneNumberId: String, code: String) -> Request<ClientResponse<PhoneNumber>> {
    Request(
      path: "/v1/me/phone_numbers/\(phoneNumberId)/attempt_verification",
      method: .post,
      scopedToActiveSession: true,
      body: ["code": code]
    )
  }

  package static func makeDefaultSecondFactor(phoneNumberId: String) -> Request<ClientResponse<PhoneNumber>> {
    Request(
      path: "/v1/me/phone_numbers/\(phoneNumberId)",
      method: .patch,
      scopedToActiveSession: true,
      body: ["default_second_factor": true]
    )
  }

  package static func setReservedForSecondFactor(phoneNumberId: String, reserved: Bool) -> Request<ClientResponse<PhoneNumber>> {
    Request(
      path: "/v1/me/phone_numbers/\(phoneNumberId)",
      method: .patch,
      scopedToActiveSession: true,
      body: ["reserved_for_second_factor": reserved]
    )
  }
}
