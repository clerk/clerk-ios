#if canImport(AuthenticationServices) && !os(watchOS)

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
}

#endif
