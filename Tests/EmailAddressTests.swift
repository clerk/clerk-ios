import ConcurrencyExtras
import FactoryKit
import Foundation
import Mocker
import Testing

@testable import Clerk

// Any test that accesses Container.shared or performs networking
// should be placed in the serialized tests below

@Suite(.serialized) final class EmailAddressSerializedTests {

  init() {
    Container.shared.clerk.register { @MainActor in
      let clerk = Clerk()
      clerk.client = .mock
      return clerk
    }
  }

  deinit {
    Container.shared.reset()
  }

  @Test func testPrepareVerificationRequest() async throws {
    let requestHandled = LockIsolated(false)
    let emailAddress = EmailAddress.mock
    let originalUrl = mockBaseUrl.appending(path: "/v1/me/email_addresses/\(emailAddress.id)/prepare_verification")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<EmailAddress>(response: .mock, client: .mock))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.url!.query()!.contains("_clerk_session_id"))
      #expect(request.urlEncodedFormBody["strategy"] == "email_code")
      requestHandled.setValue(true)
    }
    mock.register()
    try await emailAddress.prepareVerification(strategy: .emailCode)
    #expect(requestHandled.value)
  }

  @Test func testAttemptVerificationRequest() async throws {
    let requestHandled = LockIsolated(false)
    let emailAddress = EmailAddress.mock
    let code = "12345"
    let originalUrl = mockBaseUrl.appending(path: "/v1/me/email_addresses/\(emailAddress.id)/attempt_verification")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<EmailAddress>(response: .mock, client: .mock))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.url!.query()!.contains("_clerk_session_id"))
      #expect(request.urlEncodedFormBody["code"] == code)
      requestHandled.setValue(true)
    }
    mock.register()
    try await emailAddress.attemptVerification(strategy: .emailCode(code: "12345"))
    #expect(requestHandled.value)
  }

  @Test func testDestroyRequest() async throws {
    let requestHandled = LockIsolated(false)
    let emailAddress = EmailAddress.mock
    let originalUrl = mockBaseUrl.appending(path: "/v1/me/email_addresses/\(emailAddress.id)")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: try! JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>(response: .mock, client: .mock))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "DELETE")
      #expect(request.url!.query()!.contains("_clerk_session_id"))
      requestHandled.setValue(true)
    }
    mock.register()
    try await emailAddress.destroy()
    #expect(requestHandled.value)
  }

}
