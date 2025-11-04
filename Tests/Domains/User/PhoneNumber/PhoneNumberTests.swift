import FactoryTesting
import Foundation
import Mocker
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct PhoneNumberTests {

  init() {
    configureClerkForTesting()
  }

  @Test(.container)
  func testCreate() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/phone_numbers")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<PhoneNumber>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["phone_number"] == "+1234567890")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await PhoneNumber.create("+1234567890")
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testDelete() async throws {
    let phoneNumber = PhoneNumber.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/phone_numbers/\(phoneNumber.id)")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: try! JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await phoneNumber.delete()
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testPrepareVerification() async throws {
    let phoneNumber = PhoneNumber.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/phone_numbers/\(phoneNumber.id)/prepare_verification")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<PhoneNumber>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "phone_code")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await phoneNumber.prepareVerification()
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testAttemptVerification() async throws {
    let phoneNumber = PhoneNumber.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/phone_numbers/\(phoneNumber.id)/attempt_verification")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<PhoneNumber>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["code"] == "123456")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await phoneNumber.attemptVerification(code: "123456")
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testMakeDefaultSecondFactor() async throws {
    let phoneNumber = PhoneNumber.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/phone_numbers/\(phoneNumber.id)")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .patch: try! JSONEncoder.clerkEncoder.encode(ClientResponse<PhoneNumber>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.urlEncodedFormBody!["default_second_factor"] == "1")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await phoneNumber.makeDefaultSecondFactor()
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testSetReservedForSecondFactor() async throws {
    let phoneNumber = PhoneNumber.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/phone_numbers/\(phoneNumber.id)")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .patch: try! JSONEncoder.clerkEncoder.encode(ClientResponse<PhoneNumber>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.urlEncodedFormBody!["reserved_for_second_factor"] == "1")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await phoneNumber.setReservedForSecondFactor(reserved: true)
    #expect(requestHandled.value)
  }
}

