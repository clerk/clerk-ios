@testable import ClerkKit
import Foundation
import Testing

struct AppAccountTokenTests {
  @Test
  func uuidV5MatchesRFC4122TestVector() throws {
    // RFC 4122 DNS namespace.
    let dnsNamespace = try #require(UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8"))
    let uuid = UUID(v5Namespace: dnsNamespace, name: "www.example.com")

    #expect(uuid == UUID(uuidString: "2ed6657d-e927-568b-95e1-2665a8aea6a2"))
  }

  @MainActor
  @Test
  func appAccountTokenIsDeterministic() {
    let userId = "user_2x1aBcD3fGhIjKlMnOpQrStUvWx"

    let first = Billing.appAccountToken(forUserId: userId)
    let second = Billing.appAccountToken(forUserId: userId)

    #expect(first == second)
    #expect(first == UUID(uuidString: "8e08cd79-73d8-53ba-b576-0286add357e6"))
  }

  @MainActor
  @Test
  func appAccountTokenDiffersPerUser() {
    let first = Billing.appAccountToken(forUserId: "user_1")
    let second = Billing.appAccountToken(forUserId: "user_2")

    #expect(first != second)
  }

  @MainActor
  @Test
  func appAccountTokenHasVersion5AndRFC4122Variant() {
    let token = Billing.appAccountToken(forUserId: "user_1")
    let characters = Array(token.uuidString)

    // Version nibble is the first character of the third group.
    #expect(characters[14] == "5")
    // Variant nibble is the first character of the fourth group.
    #expect(["8", "9", "A", "B"].contains(characters[19]))
  }
}
