#if canImport(AuthenticationServices) && !os(watchOS)

import AuthenticationServices
@testable import ClerkKit
import Foundation
import Testing

@MainActor
struct PasskeyHelperTests {
  @Test
  func credentialAssertionRequestSetsAllowedCredentials() {
    let allowedCredentialID = Data([1, 2, 3, 4])

    let request = PasskeyHelper().credentialAssertionRequest(
      challenge: Data([5, 6, 7, 8]),
      relyingPartyIdentifier: "example.com",
      allowedCredentialIDs: [allowedCredentialID]
    )

    #expect(request.allowedCredentials.count == 1)
    #expect(request.allowedCredentials.first?.credentialID == allowedCredentialID)
  }

  @Test
  func credentialAssertionRequestUsesTheServersUserVerification() {
    let request = PasskeyHelper().credentialAssertionRequest(
      challenge: Data([5, 6, 7, 8]),
      relyingPartyIdentifier: "example.com",
      userVerification: "required"
    )

    #expect(request.userVerificationPreference == .required)
  }

  @Test
  func credentialAssertionRequestKeepsTheSystemDefaultWithoutUserVerification() {
    let request = PasskeyHelper().credentialAssertionRequest(
      challenge: Data([5, 6, 7, 8]),
      relyingPartyIdentifier: "example.com"
    )

    #expect(request.userVerificationPreference == .preferred)
  }

  @Test
  func credentialRegistrationRequestRequiresUserVerification() {
    let request = PasskeyHelper().credentialRegistrationRequest(
      challenge: Data([5, 6, 7, 8]),
      name: "user@example.com",
      userId: Data([1, 2, 3, 4]),
      relyingPartyIdentifier: "example.com"
    )

    #expect(request.userVerificationPreference == .required)
  }

  @Test
  func passwordCredentialIsAccepted() throws {
    let credential = ASPasswordCredential(user: "user+clerk_test@example.com", password: "password")

    try PasskeyHelper.acceptCredential(credential)
  }

  @Test
  func unsupportedCredentialEndsTheRequestWithAnErrorInsteadOfCrashing() {
    #expect(throws: ClerkClientError.self) {
      try PasskeyHelper.acceptCredential(UnsupportedCredential())
    }
  }
}

@objc(ClerkTestsUnsupportedCredential)
private final class UnsupportedCredential: NSObject, ASAuthorizationCredential {
  static let supportsSecureCoding = true

  override init() {}

  required init?(coder _: NSCoder) {
    super.init()
  }

  func encode(with _: NSCoder) {}

  func copy(with _: NSZone? = nil) -> Any {
    self
  }
}

#endif
