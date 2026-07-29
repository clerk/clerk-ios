import Foundation

enum TokenFreshness {
  enum TieBreaker {
    case existing
    case incoming
  }

  static func pickFreshest(
    existing: TokenResource?,
    incoming: TokenResource,
    now: Date = .now,
    tieBreaker: TieBreaker = .incoming
  ) -> TokenResource {
    guard let existing else {
      return incoming
    }

    let existingJWT = try? DecodedJWT(jwt: existing.jwt)
    let incomingJWT = try? DecodedJWT(jwt: incoming.jwt)

    if let expiresAt = existingJWT?.expiresAt, expiresAt <= now {
      return incoming
    }

    guard let existingJWT, let incomingJWT else {
      return incoming
    }

    guard existingJWT.sessionId == incomingJWT.sessionId,
          normalizedOrganizationId(existingJWT.organizationId)
          == normalizedOrganizationId(incomingJWT.organizationId)
    else {
      return incoming
    }

    switch (existingJWT.originIssuedAt, incomingJWT.originIssuedAt) {
    case (nil, nil):
      return pickByIssuedAt(
        existing: existing,
        existingJWT: existingJWT,
        incoming: incoming,
        incomingJWT: incomingJWT,
        tieBreaker: tieBreaker
      )
    case (.some, nil):
      return existing
    case (nil, .some):
      return incoming
    case (.some(let existingOriginIssuedAt), .some(let incomingOriginIssuedAt)):
      if existingOriginIssuedAt > incomingOriginIssuedAt {
        return existing
      }
      if incomingOriginIssuedAt > existingOriginIssuedAt {
        return incoming
      }

      return pickByIssuedAt(
        existing: existing,
        existingJWT: existingJWT,
        incoming: incoming,
        incomingJWT: incomingJWT,
        tieBreaker: tieBreaker
      )
    }
  }

  private static func pickByIssuedAt(
    existing: TokenResource,
    existingJWT: DecodedJWT,
    incoming: TokenResource,
    incomingJWT: DecodedJWT,
    tieBreaker: TieBreaker
  ) -> TokenResource {
    let existingIssuedAt = existingJWT.issuedAt?.timeIntervalSince1970 ?? 0
    let incomingIssuedAt = incomingJWT.issuedAt?.timeIntervalSince1970 ?? 0

    if existingIssuedAt > incomingIssuedAt {
      return existing
    }
    if incomingIssuedAt > existingIssuedAt {
      return incoming
    }
    switch tieBreaker {
    case .existing:
      return existing
    case .incoming:
      return incoming
    }
  }

  static func matches(
    _ token: TokenResource,
    sessionId: String,
    organizationId: String?
  ) -> Bool {
    guard let jwt = try? DecodedJWT(jwt: token.jwt) else {
      return true
    }
    guard let tokenSessionId = jwt.sessionId else {
      return true
    }
    return tokenSessionId == sessionId
      && normalizedOrganizationId(jwt.organizationId) == normalizedOrganizationId(organizationId)
  }

  static func normalizedOrganizationId(_ organizationId: String?) -> String {
    organizationId ?? ""
  }
}
