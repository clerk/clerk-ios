import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct EmailAddressTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func testCreate() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/email_addresses")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<EmailAddress>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["email_address"] == "test@example.com")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await EmailAddress.create("test@example.com")
    #expect(requestHandled.value)
  }

  @Test
  func testPrepareVerification() async throws {
    let emailAddress = EmailAddress.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/email_addresses/\(emailAddress.id)/prepare_verification")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<EmailAddress>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "email_code")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await emailAddress.prepareVerification(strategy: .emailCode)
    #expect(requestHandled.value)
  }

  @Test
  func testAttemptVerification() async throws {
    let emailAddress = EmailAddress.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/email_addresses/\(emailAddress.id)/attempt_verification")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<EmailAddress>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["code"] == "123456")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await emailAddress.attemptVerification(strategy: .emailCode(code: "123456"))
    #expect(requestHandled.value)
  }

  @Test
  func testDestroy() async throws {
    let emailAddress = EmailAddress.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/email_addresses/\(emailAddress.id)")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: try! JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await emailAddress.destroy()
    #expect(requestHandled.value)
  }
}
