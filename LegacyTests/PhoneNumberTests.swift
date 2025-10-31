import ConcurrencyExtras
import FactoryKit
import Foundation
import Mocker
import Testing

@testable import ClerkKit

@Suite(.serialized) final class SerializedPhoneNumberTests {

  init() {
    Container.shared.clerk.register { @MainActor in
      let clerk = Clerk()
      clerk.client = .mock
      return clerk
    }
  }

  deinit {
    TestContainer.reset()
  }

  @Test func testDelete() async throws {
    let requestHandled = LockIsolated(false)
    let phoneNumber = PhoneNumber.mock
    let originalUrl = mockBaseUrl.appending(path: "/v1/me/phone_numbers/\(phoneNumber.id)")
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
    try await phoneNumber.delete()
    #expect(requestHandled.value)
  }

  @Test func testPrepareVerification() async throws {
    let requestHandled = LockIsolated(false)
    let phoneNumber = PhoneNumber.mock
    let originalUrl = mockBaseUrl.appending(path: "/v1/me/phone_numbers/\(phoneNumber.id)/prepare_verification")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<PhoneNumber>(response: .mock, client: .mock))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.url!.query()!.contains("_clerk_session_id"))
      requestHandled.setValue(true)
    }
    mock.register()
    try await phoneNumber.prepareVerification()
    #expect(requestHandled.value)
  }

  @Test func testAttemptVerification() async throws {
    let requestHandled = LockIsolated(false)
    let phoneNumber = PhoneNumber.mock
    let code = "12345"
    let originalUrl = mockBaseUrl.appending(path: "/v1/me/phone_numbers/\(phoneNumber.id)/attempt_verification")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<PhoneNumber>(response: .mock, client: .mock))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.url!.query()!.contains("_clerk_session_id"))
      #expect(request.urlEncodedFormBody["code"] == code)
      requestHandled.setValue(true)
    }
    mock.register()
    try await phoneNumber.attemptVerification(code: code)
    #expect(requestHandled.value)
  }

  @Test func testMakeDefaultSecondFactor() async throws {
    let requestHandled = LockIsolated(false)
    let phoneNumber = PhoneNumber.mock
    let originalUrl = mockBaseUrl.appending(path: "/v1/me/phone_numbers/\(phoneNumber.id)")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .patch: try! JSONEncoder.clerkEncoder.encode(ClientResponse<PhoneNumber>(response: .mock, client: .mock))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.url!.query()!.contains("_clerk_session_id"))
      #expect(request.urlEncodedFormBody["default_second_factor"] == String(describing: NSNumber(booleanLiteral: true)))
      requestHandled.setValue(true)
    }
    mock.register()
    try await phoneNumber.makeDefaultSecondFactor()
    #expect(requestHandled.value)
  }

  @Test func testSetReservedForSecondFactor() async throws {
    let requestHandled = LockIsolated(false)
    let phoneNumber = PhoneNumber.mock
    let originalUrl = mockBaseUrl.appending(path: "/v1/me/phone_numbers/\(phoneNumber.id)")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .patch: try! JSONEncoder.clerkEncoder.encode(ClientResponse<PhoneNumber>(response: .mock, client: .mock))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.url!.query()!.contains("_clerk_session_id"))
      #expect(request.urlEncodedFormBody["reserved_for_second_factor"] == String(describing: NSNumber(booleanLiteral: true)))
      requestHandled.setValue(true)
    }
    mock.register()
    try await phoneNumber.setReservedForSecondFactor()
    #expect(requestHandled.value)
  }

}
