//
//  EmailAddressTests.swift
//  Clerk
//
//  Created by Mike Pitre on 1/1/26.
//

import Foundation
import Testing

@testable import ClerkKit

@Suite(.serialized)
struct EmailAddressTests {

  @Test
  @MainActor
  func testCreate() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    _ = try? await EmailAddress.create("test@example.com")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/email_addresses", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/email_addresses"))
    #expect(verification.hasMethod("POST"))
    #expect(verification.hasQueryParameter("_clerk_session_id", value: "1"))

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["email_address"] == "test@example.com")
  }

  @Test
  @MainActor
  func testPrepareVerification() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let emailAddress = EmailAddress.mock
    _ = try? await emailAddress.prepareVerification(strategy: .emailCode)

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/email_addresses/\(emailAddress.id)/prepare_verification", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/email_addresses/\(emailAddress.id)/prepare_verification"))
    #expect(verification.hasMethod("POST"))

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "email_code")
  }

  @Test
  @MainActor
  func testAttemptVerification() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let emailAddress = EmailAddress.mock
    _ = try? await emailAddress.attemptVerification(strategy: .emailCode(code: "123456"))

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/email_addresses/\(emailAddress.id)/attempt_verification", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/email_addresses/\(emailAddress.id)/attempt_verification"))
    #expect(verification.hasMethod("POST"))

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["code"] == "123456")
  }

  @Test
  @MainActor
  func testDestroy() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    let emailAddress = EmailAddress.mock
    _ = try? await emailAddress.destroy()

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/email_addresses/\(emailAddress.id)", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/email_addresses/\(emailAddress.id)"))
    #expect(verification.hasMethod("DELETE"))
    #expect(verification.hasQueryParameter("_clerk_session_id", value: "1"))
  }
}
