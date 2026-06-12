@testable import ClerkKit
import Foundation
import Testing

struct JSONWebAuthnTests {
  @Test
  func assertionRelyingPartyIdentifierReadsNonce() throws {
    let nonce = try JSON([
      "rpId": "example.com",
    ])

    #expect(nonce.webAuthnAssertionRelyingPartyIdentifier == "example.com")
  }

  @Test
  func assertionAllowedCredentialIDsDecodeBase64URLIDs() throws {
    let nonce = try JSON([
      "allowCredentials": [
        [
          "type": "public-key",
          "id": "AQIDBA",
          "transports": ["internal", "hybrid"],
        ],
        [
          "type": "public-key",
          "id": "aGVsbG8",
        ],
      ],
    ])

    #expect(nonce.webAuthnAssertionAllowedCredentialIDs == [
      Data([1, 2, 3, 4]),
      Data("hello".utf8),
    ])
  }

  @Test
  func assertionAllowedCredentialIDsIgnoreInvalidEntries() throws {
    let nonce = try JSON([
      "allowCredentials": [
        ["type": "public-key"],
        ["type": "public-key", "id": ""],
        ["type": "public-key", "id": "!!!"],
        ["type": "public-key", "id": "AQID"],
      ],
    ])

    #expect(nonce.webAuthnAssertionAllowedCredentialIDs == [
      Data([1, 2, 3]),
    ])
  }
}
