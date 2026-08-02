@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@MainActor
@Suite(.serialized)
struct TrustedDeviceServiceTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func list() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/trusted_devices")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(ClientResponse<[TrustedDevice]>(response: [.mock], client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "GET")
      requestHandled.setValue(true)
    }
    mock.register()

    let trustedDevices = try await Clerk.shared.dependencies.trustedDeviceService.list()

    #expect(requestHandled.value)
    #expect(trustedDevices == [.mock])
  }

  @Test
  func prepareEnrollment() async throws {
    let sessionId = "sess_enrollment"
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/trusted_devices/prepare")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<TrustedDeviceChallenge>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(request.url?.queryParam(named: "_clerk_session_id") == sessionId)
      #expect(request.urlEncodedFormBody?["platform"] == "ios")
      #expect(request.urlEncodedFormBody?["app_identifier"] == "com.clerk.example")
      #expect(request.urlEncodedFormBody?["name"] == "Sean's iPhone")
      #expect(request.urlEncodedFormBody?["algorithm"] == "ES256")
      #expect(request.urlEncodedFormBody?["public_key_jwk"] == "{\"kty\":\"EC\"}")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.trustedDeviceService.prepareEnrollment(
      sessionId: sessionId,
      params: .init(
        appIdentifier: "com.clerk.example",
        name: "Sean's iPhone",
        publicKeyJWK: "{\"kty\":\"EC\"}"
      )
    )

    #expect(requestHandled.value)
  }

  @Test
  func attemptEnrollment() async throws {
    let sessionId = "sess_enrollment"
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/trusted_devices/attempt")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<TrustedDevice>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(request.url?.queryParam(named: "_clerk_session_id") == sessionId)
      #expect(request.urlEncodedFormBody?["platform"] == "ios")
      #expect(request.urlEncodedFormBody?["app_identifier"] == "com.clerk.example")
      #expect(request.urlEncodedFormBody?["name"] == "Sean's iPhone")
      #expect(request.urlEncodedFormBody?["algorithm"] == "ES256")
      #expect(request.urlEncodedFormBody?["public_key_jwk"] == "{\"kty\":\"EC\"}")
      #expect(request.urlEncodedFormBody?["client_data"] == "{\"challenge_id\":\"tdch_123\"}")
      #expect(request.urlEncodedFormBody?["signature"] == "mock_signature")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.trustedDeviceService.attemptEnrollment(
      sessionId: sessionId,
      params: .init(
        appIdentifier: "com.clerk.example",
        name: "Sean's iPhone",
        publicKeyJWK: "{\"kty\":\"EC\"}",
        clientData: "{\"challenge_id\":\"tdch_123\"}",
        signature: "mock_signature"
      )
    )

    #expect(requestHandled.value)
  }

  @Test
  func validateSignInCredential() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/trusted_devices/validate")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          ClientResponse<TrustedDeviceValidation>(
            response: .init(valid: true),
            client: .mock
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody?["trusted_device_id"] == "tdc_123")
      requestHandled.setValue(true)
    }
    mock.register()

    let validation = try await Clerk.shared.dependencies.trustedDeviceService.validateSignInCredential(
      trustedDeviceId: "tdc_123"
    )

    #expect(requestHandled.value)
    #expect(validation == .init(valid: true))
  }

  @Test
  func revoke() async throws {
    let trustedDevice = TrustedDevice.mock
    let sessionId = "sess_enrollment"
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/trusted_devices/\(trustedDevice.id)")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: JSONEncoder.clerkEncoder.encode(ClientResponse<TrustedDevice>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "DELETE")
      #expect(request.url?.queryParam(named: "_clerk_session_id") == sessionId)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.trustedDeviceService.revoke(
      trustedDeviceId: trustedDevice.id,
      sessionId: sessionId
    )

    #expect(requestHandled.value)
  }
}
