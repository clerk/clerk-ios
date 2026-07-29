@testable import ClerkKit
import Foundation
import Testing

struct TokenFreshnessTests {
  @Test
  func keepsTokenWithHigherOriginIssuedAt() throws {
    let existing = try token(originIssuedAt: 200, issuedAt: 200)
    let incoming = try token(originIssuedAt: 100, issuedAt: 300)

    let result = TokenFreshness.pickFreshest(existing: existing, incoming: incoming)

    #expect(result == existing)
  }

  @Test
  func usesIssuedAtToBreakEqualOriginIssuedAt() throws {
    let existing = try token(originIssuedAt: 200, issuedAt: 300)
    let incoming = try token(originIssuedAt: 200, issuedAt: 400)

    let result = TokenFreshness.pickFreshest(existing: existing, incoming: incoming)

    #expect(result == incoming)
  }

  @Test
  func usesIssuedAtWhenBothTokensLackOriginIssuedAt() throws {
    let existing = try token(originIssuedAt: nil, issuedAt: 300)
    let incoming = try token(originIssuedAt: nil, issuedAt: 200)

    let result = TokenFreshness.pickFreshest(existing: existing, incoming: incoming)

    #expect(result == existing)
  }

  @Test
  func acceptsIncomingTokenOnFullTimestampTie() throws {
    let existing = try token(originIssuedAt: 200, issuedAt: 300, signature: "existing")
    let incoming = try token(originIssuedAt: 200, issuedAt: 300, signature: "incoming")

    let result = TokenFreshness.pickFreshest(existing: existing, incoming: incoming)

    #expect(result == incoming)
  }

  @Test
  func keepsExistingTokenOnFullTimestampTieWhenRequested() throws {
    let existing = try token(originIssuedAt: 200, issuedAt: 300, signature: "existing")
    let incoming = try token(originIssuedAt: 200, issuedAt: 300, signature: "incoming")

    let result = TokenFreshness.pickFreshest(
      existing: existing,
      incoming: incoming,
      tieBreaker: .existing
    )

    #expect(result == existing)
  }

  @Test
  func acceptsIncomingTokenWhenOrganizationChanges() throws {
    let existing = try token(
      organizationId: "org_one",
      originIssuedAt: 300,
      issuedAt: 300
    )
    let incoming = try token(
      organizationId: "org_two",
      originIssuedAt: 100,
      issuedAt: 100
    )

    let result = TokenFreshness.pickFreshest(existing: existing, incoming: incoming)

    #expect(result == incoming)
  }

  @Test
  func treatsTokenWithoutOriginIssuedAtAsOlder() throws {
    let existing = try token(originIssuedAt: 200, issuedAt: 200)
    let incoming = try token(originIssuedAt: nil, issuedAt: 300)

    let result = TokenFreshness.pickFreshest(existing: existing, incoming: incoming)

    #expect(result == existing)
  }

  @Test
  func replacesExpiredExistingToken() throws {
    let now = Date(timeIntervalSince1970: 1000)
    let existing = try token(
      originIssuedAt: 300,
      issuedAt: 300,
      expiresAt: 900
    )
    let incoming = try token(
      originIssuedAt: 100,
      issuedAt: 100,
      expiresAt: 2000
    )

    let result = TokenFreshness.pickFreshest(
      existing: existing,
      incoming: incoming,
      now: now
    )

    #expect(result == incoming)
  }

  private func token(
    sessionId: String = "sess_test",
    organizationId: String? = nil,
    originIssuedAt: Int?,
    issuedAt: Int,
    expiresAt: Int = 4_000_000_000,
    signature: String = "signature"
  ) throws -> TokenResource {
    var header: [String: Any] = ["alg": "none", "typ": "JWT"]
    if let originIssuedAt {
      header["oiat"] = originIssuedAt
    }

    var claims: [String: Any] = [
      "sid": sessionId,
      "iat": issuedAt,
      "exp": expiresAt,
    ]
    if let organizationId {
      claims["org_id"] = organizationId
    }

    return try TokenResource(
      jwt: testJWT(header: header, claims: claims, signature: signature)
    )
  }
}
