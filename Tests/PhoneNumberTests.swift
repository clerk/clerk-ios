//
//  PhoneNumberTests.swift
//  Clerk
//
//  Created by Mike Pitre on 1/1/26.
//

import Foundation
import Testing

@testable import ClerkKit

@Suite(.serialized)
struct PhoneNumberTests {

  @Test
  @MainActor
  func testCreate() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    _ = try? await PhoneNumber.create("+15551234567")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/phone_numbers", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/phone_numbers"))
    #expect(verification.hasMethod("POST"))
    #expect(verification.hasQueryParameter("_clerk_session_id", value: "1"))

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["phone_number"] == "+15551234567")
  }

  @Test
  @MainActor
  func testDelete() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    var phoneNumber = PhoneNumber.mock
    _ = try? await phoneNumber.delete()

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/phone_numbers/\(phoneNumber.id)", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/phone_numbers/\(phoneNumber.id)"))
    #expect(verification.hasMethod("DELETE"))
    #expect(verification.hasQueryParameter("_clerk_session_id", value: "1"))
  }

  @Test
  @MainActor
  func testPrepareVerification() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    var phoneNumber = PhoneNumber.mock
    _ = try? await phoneNumber.prepareVerification()

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/phone_numbers/\(phoneNumber.id)/prepare_verification", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/phone_numbers/\(phoneNumber.id)/prepare_verification"))
    #expect(verification.hasMethod("POST"))

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "phone_code")
  }

  @Test
  @MainActor
  func testAttemptVerification() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    var phoneNumber = PhoneNumber.mock
    _ = try? await phoneNumber.attemptVerification(code: "123456")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/phone_numbers/\(phoneNumber.id)/attempt_verification", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/phone_numbers/\(phoneNumber.id)/attempt_verification"))
    #expect(verification.hasMethod("POST"))

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["code"] == "123456")
  }

  @Test
  @MainActor
  func testMakeDefaultSecondFactor() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    var phoneNumber = PhoneNumber.mock
    _ = try? await phoneNumber.makeDefaultSecondFactor()

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/phone_numbers/\(phoneNumber.id)", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/phone_numbers/\(phoneNumber.id)"))
    #expect(verification.hasMethod("PATCH"))

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["default_second_factor"] == "1")  // URL-encoded form encodes booleans as "1" or "0"
  }

  @Test
  @MainActor
  func testSetReservedForSecondFactor() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    var phoneNumber = PhoneNumber.mock
    _ = try? await phoneNumber.setReservedForSecondFactor(reserved: true)

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/phone_numbers/\(phoneNumber.id)", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/phone_numbers/\(phoneNumber.id)"))
    #expect(verification.hasMethod("PATCH"))

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["reserved_for_second_factor"] == "1")  // URL-encoded form encodes booleans as "1" or "0"
  }
}
