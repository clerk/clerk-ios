//
//  PasskeyTests.swift
//  Clerk
//
//  Created by Mike Pitre on 1/1/26.
//

import Foundation
import Testing

@testable import ClerkKit

@Suite(.serialized)
struct PasskeyTests {

  #if canImport(AuthenticationServices) && !os(watchOS)

  @Test
  @MainActor
  func testCreate() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    _ = try? await Passkey.create()

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/passkeys", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/passkeys"))
    #expect(verification.hasMethod("POST"))
    #expect(verification.hasQueryParameter("_clerk_session_id", value: "1"))
  }

  @Test
  @MainActor
  func testUpdate() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let passkey = Passkey.mock
    _ = try? await passkey.update(name: "My Passkey")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/passkeys/\(passkey.id)", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/passkeys/\(passkey.id)"))
    #expect(verification.hasMethod("PATCH"))

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["name"] == "My Passkey")
  }

  @Test
  @MainActor
  func testAttemptVerification() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let passkey = Passkey.mock
    _ = try? await passkey.attemptVerification(credential: "credential_data")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/passkeys/\(passkey.id)/attempt_verification", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/passkeys/\(passkey.id)/attempt_verification"))
    #expect(verification.hasMethod("POST"))

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "passkey")
    #expect(bodyParams["public_key_credential"] == "credential_data")
  }

  @Test
  @MainActor
  func testDelete() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let passkey = Passkey.mock
    _ = try? await passkey.delete()

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/passkeys/\(passkey.id)", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/passkeys/\(passkey.id)"))
    #expect(verification.hasMethod("DELETE"))
    #expect(verification.hasQueryParameter("_clerk_session_id", value: "1"))
  }

  #endif
}

