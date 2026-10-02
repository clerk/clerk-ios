//
//  FakeTransport+PreviewDefaults.swift
//  Clerk
//

import Foundation

extension FakeTransport {
  package static func previewDefaults() -> FakeTransport {
    let transport = FakeTransport()
    let anyId = FakeTransport.anyPathSegment

    transport.stub(EmailAddressAPI.create(email: EmailAddress.mock.emailAddress), returning: ClientResponse(response: EmailAddress.mock, client: nil))
    transport.stub(EmailAddressAPI.prepareVerification(emailAddressId: anyId, strategy: .emailCode), returning: ClientResponse(response: EmailAddress.mock, client: nil))
    transport.stub(EmailAddressAPI.attemptVerification(emailAddressId: anyId, strategy: .emailCode(code: "424242")), returning: ClientResponse(response: EmailAddress.mock, client: nil))
    transport.stub(EmailAddressAPI.destroy(emailAddressId: anyId), returning: ClientResponse(response: DeletedObject.mock, client: nil))

    return transport
  }
}
