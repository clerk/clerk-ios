@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@MainActor
@Suite(.serialized)
struct BiometricCredentialServiceTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func list() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/biometric_credentials")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(ClientResponse<[BiometricCredential]>(response: [.mock], client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "GET")
      requestHandled.setValue(true)
    }
    mock.register()

    let biometricCredentials = try await Clerk.shared.dependencies.biometricCredentialService.list()

    #expect(requestHandled.value)
    #expect(biometricCredentials == [.mock])
  }

  @Test
  func prepareEnrollment() async throws {
    let sessionId = "sess_enrollment"
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/biometric_credentials/prepare")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<BiometricCredentialChallenge>(response: .mock, client: .mock)),
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

    _ = try await Clerk.shared.dependencies.biometricCredentialService.prepareEnrollment(
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
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/biometric_credentials/attempt")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<BiometricCredential>(response: .mock, client: .mock)),
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

    _ = try await Clerk.shared.dependencies.biometricCredentialService.attemptEnrollment(
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
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/biometric_credentials/validate")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          ClientResponse<BiometricCredentialValidation>(
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

    let validation = try await Clerk.shared.dependencies.biometricCredentialService.validateSignInCredential(
      biometricCredentialId: "tdc_123"
    )

    #expect(requestHandled.value)
    #expect(validation == .init(valid: true))
  }

  @Test
  func revoke() async throws {
    let biometricCredential = BiometricCredential.mock
    let sessionId = "sess_enrollment"
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/biometric_credentials/\(biometricCredential.id)")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: JSONEncoder.clerkEncoder.encode(ClientResponse<BiometricCredential>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "DELETE")
      #expect(request.url?.queryParam(named: "_clerk_session_id") == sessionId)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.biometricCredentialService.revoke(
      biometricCredentialId: biometricCredential.id,
      sessionId: sessionId
    )

    #expect(requestHandled.value)
  }
}
