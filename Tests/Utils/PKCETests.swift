@testable import ClerkKit
import Foundation
import Testing

struct PKCETests {
  @Test
  func pkceChallengeMatchesRFC7636Vector() {
    let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"

    #expect(PKCE.challenge(for: verifier) == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
  }

  @Test
  func generatedPKCEPairUsesS256CompatibleValues() throws {
    let pair = try PKCE.generatePair()

    #expect(pair.verifier.count == 43)
    #expect(pair.challenge.count == 43)
    #expect(pair.verifier.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
    #expect(pair.challenge == PKCE.challenge(for: pair.verifier))
  }
}
