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
}

#endif
