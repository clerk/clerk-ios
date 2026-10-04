//
//  FakeTransport+MockDefaults.swift
//  Clerk
//

import Foundation

extension FakeTransport {
  /// A transport that answers every endpoint with its `.mock` fixture until a stub overrides it.
  package static func mockDefaults() -> FakeTransport {
    let transport = FakeTransport()
    let anyId = FakeTransport.anyPathSegment

    transport.fallback(ClientAPI.get(), returning: ClientResponse(response: Client.mock, client: nil))

    transport.fallback(EnvironmentAPI.get(), returning: .mock)

    transport.fallback(EmailAddressAPI.create(email: EmailAddress.mock.emailAddress), returning: ClientResponse(response: EmailAddress.mock, client: nil))
    transport.fallback(EmailAddressAPI.prepareVerification(emailAddressId: anyId, strategy: .emailCode), returning: ClientResponse(response: EmailAddress.mock, client: nil))
    transport.fallback(EmailAddressAPI.attemptVerification(emailAddressId: anyId, strategy: .emailCode(code: "424242")), returning: ClientResponse(response: EmailAddress.mock, client: nil))
    transport.fallback(EmailAddressAPI.destroy(emailAddressId: anyId), returning: ClientResponse(response: DeletedObject.mock, client: nil))

    transport.fallback(
      MagicLinkAPI.complete(params: MagicLinkCompleteParams(flowId: anyId, approvalToken: "", codeVerifier: "")),
      returning: ClientResponse(response: .ticket(MagicLinkCompleteResponse(flowId: nil, ticket: "ticket_mock")), client: nil)
    )

    return transport
  }
}
