//
//  UserTests.swift
//  Clerk
//
//  Created by Mike Pitre on 1/1/26.
//

import Foundation
import Testing

@testable import ClerkKit

@Suite(.serialized)
struct UserTests {

  @Test
  @MainActor
  func testReload() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    var user = User.mock
    _ = try? await user.reload()

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me"))
    #expect(verification.hasMethod("GET"))
    #expect(verification.hasQueryParameter("_clerk_session_id", value: "1"))
  }

  @Test
  @MainActor
  func testUpdate() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    var user = User.mock
    let params = User.UpdateParams(firstName: "John", lastName: "Doe")
    _ = try? await user.update(params)

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me"))
    #expect(verification.hasMethod("PATCH"))

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["first_name"] == "John")
    #expect(bodyParams["last_name"] == "Doe")
  }

  @Test
  @MainActor
  func testCreateBackupCodes() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    var user = User.mock
    _ = try? await user.createBackupCodes()

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/backup_codes", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/backup_codes"))
    #expect(verification.hasMethod("POST"))
  }

  @Test
  @MainActor
  func testCreateEmailAddress() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    var user = User.mock
    _ = try? await user.createEmailAddress("test@example.com")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/email_addresses", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/email_addresses"))
    #expect(verification.hasMethod("POST"))
  }

  @Test
  @MainActor
  func testCreatePhoneNumber() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    var user = User.mock
    _ = try? await user.createPhoneNumber("+15551234567")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/phone_numbers", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/phone_numbers"))
    #expect(verification.hasMethod("POST"))
  }

  @Test
  @MainActor
  func testCreateExternalAccount() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    var user = User.mock
    _ = try? await user.createExternalAccount(provider: .google, redirectUrl: nil, additionalScopes: nil)

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/external_accounts", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/external_accounts"))
    #expect(verification.hasMethod("POST"))

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "oauth_google")
  }

  @Test
  @MainActor
  func testCreateExternalAccountToken() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    var user = User.mock
    _ = try? await user.createExternalAccount(provider: .apple, idToken: "token123")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/external_accounts", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/external_accounts"))
    #expect(verification.hasMethod("POST"))

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "oauth_token_apple")
    #expect(bodyParams["token"] == "token123")
  }

  @Test
  @MainActor
  func testCreateTotp() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    var user = User.mock
    _ = try? await user.createTOTP()

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/totp", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/totp"))
    #expect(verification.hasMethod("POST"))
  }

  @Test
  @MainActor
  func testVerifyTotp() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    var user = User.mock
    _ = try? await user.verifyTOTP(code: "123456")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/totp/attempt_verification", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/totp/attempt_verification"))
    #expect(verification.hasMethod("POST"))

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["code"] == "123456")
  }

  @Test
  @MainActor
  func testDisableTotp() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    var user = User.mock
    _ = try? await user.disableTOTP()

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/totp", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/totp"))
    #expect(verification.hasMethod("DELETE"))
  }

  @Test
  @MainActor
  func testGetOrganizationInvitations() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    var user = User.mock
    _ = try? await user.getOrganizationInvitations(initialPage: 0, pageSize: 10)

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/organization_invitations", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/organization_invitations"))
    #expect(verification.hasMethod("GET"))
    #expect(verification.hasQueryParameter("offset", value: "0"))
    #expect(verification.hasQueryParameter("limit", value: "10"))
  }

  @Test
  @MainActor
  func testGetOrganizationMemberships() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    var user = User.mock
    _ = try? await user.getOrganizationMemberships(initialPage: 0, pageSize: 10)

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/organization_memberships", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/organization_memberships"))
    #expect(verification.hasMethod("GET"))
    #expect(verification.hasQueryParameter("paginated", value: "true"))
  }

  @Test
  @MainActor
  func testGetOrganizationSuggestions() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    var user = User.mock
    _ = try? await user.getOrganizationSuggestions(initialPage: 0, pageSize: 10, status: "pending")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/organization_suggestions", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/organization_suggestions"))
    #expect(verification.hasMethod("GET"))
    #expect(verification.hasQueryParameter("status", value: "pending"))
  }

  @Test
  @MainActor
  func testGetSessions() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    var user = User.mock
    _ = try? await user.getSessions()

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/sessions/active", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/sessions/active"))
    #expect(verification.hasMethod("GET"))
  }

  @Test
  @MainActor
  func testUpdatePassword() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    var user = User.mock
    let params = User.UpdatePasswordParams(currentPassword: "oldpass", newPassword: "newpass123")
    _ = try? await user.updatePassword(params)

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/change_password", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/change_password"))
    #expect(verification.hasMethod("POST"))

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["current_password"] == "oldpass")
    #expect(bodyParams["new_password"] == "newpass123")
  }

  @Test
  @MainActor
  func testSetProfileImage() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    var user = User.mock
    let imageData = Data("image data".utf8)
    _ = try? await user.setProfileImage(imageData: imageData)

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/profile_image", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/profile_image"))
    #expect(verification.hasMethod("POST"))
    #expect(verification.hasHeader("Content-Type", value: nil))
    let contentType = request.value(forHTTPHeaderField: "Content-Type")
    #expect(contentType?.hasPrefix("multipart/form-data") == true)
  }

  @Test
  @MainActor
  func testDeleteProfileImage() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    var user = User.mock
    _ = try? await user.deleteProfileImage()

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me/profile_image", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me/profile_image"))
    #expect(verification.hasMethod("DELETE"))
  }

  @Test
  @MainActor
  func testDelete() async throws {
    TestContainer.reset()
    Clerk.shared.client = .mock

    var user = User.mock
    _ = try? await user.delete()

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/me", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/me"))
    #expect(verification.hasMethod("DELETE"))
  }
}
