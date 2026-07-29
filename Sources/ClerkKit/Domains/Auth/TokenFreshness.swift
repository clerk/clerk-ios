import Foundation

enum TokenFreshness {
  static func pickFreshest(
    existing: TokenResource?,
    incoming: TokenResource,
    now: Date = .now
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
      return incoming
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

      let existingIssuedAt = existingJWT.issuedAt?.timeIntervalSince1970 ?? 0
      let incomingIssuedAt = incomingJWT.issuedAt?.timeIntervalSince1970 ?? 0
      return existingIssuedAt > incomingIssuedAt ? existing : incoming
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
