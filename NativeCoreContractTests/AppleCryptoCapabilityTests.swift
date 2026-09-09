import ClerkKit
import Foundation
import Testing

@MainActor
struct AppleCryptoCapabilityTests {
  @Test func nativeSHA256MatchesThePKCERFC7636Vector() async throws {
    let capabilities = try AppleCapabilities(publishableKey: "fixture", frontendAPI: #require(URL(string: "https://example.com")), storage: UnusedCredentialStorage())
    let result = try await capabilities.perform("crypto.sha256", arguments: .object([
      "value": .string("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"),
    ]))
    #expect(result == .string("E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"))
  }
}

private actor UnusedCredentialStorage: CredentialStorage {
  func read() throws -> String? {
    throw CoreError(code: "unexpected_storage")
  }

  func write(_: String) throws {
    throw CoreError(code: "unexpected_storage")
  }

  func remove() throws {
    throw CoreError(code: "unexpected_storage")
  }
}
