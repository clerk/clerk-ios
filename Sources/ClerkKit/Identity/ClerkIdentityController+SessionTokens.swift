import Foundation

extension ClerkIdentityController {
  struct SessionTokenGeneration: Equatable {
    let sessionId: String
    let value: UInt64
    let epoch: UInt64
  }

  struct SessionTokenRequest {
    let session: Session
    let clientId: String?
    let clientResponseGeneration: ClientResponseGeneration
    let tokenGeneration: SessionTokenGeneration
    let isCurrentActiveSession: Bool
  }

  func sessionTokenGeneration(sessionId: String) -> SessionTokenGeneration {
    SessionTokenGeneration(sessionId: sessionId, value: sessionTokenGenerations[sessionId] ?? 0, epoch: sessionTokenEpoch)
  }

  func isCurrent(_ generation: SessionTokenGeneration) -> Bool {
    generation == sessionTokenGeneration(sessionId: generation.sessionId)
  }

  func invalidateSessionTokens(sessionId: String) {
    sessionTokenGenerations[sessionId] = (sessionTokenGenerations[sessionId] ?? 0) &+ 1
    invalidatedSessionTokens.insert(sessionId)
    SessionTemplateTokensCache.shared.removeTokens(sessionId: sessionId)
  }

  func invalidateAllSessionTokens() {
    sessionTokenEpoch &+= 1
    sessionTokenGenerations.removeAll()
    invalidatedSessionTokens.formUnion(clerk?.client?.sessions.map(\.id) ?? [])
    SessionTemplateTokensCache.shared.clear()
  }

  func canReuseSessionToken(sessionId: String) -> Bool {
    !invalidatedSessionTokens.contains(sessionId)
  }

  func makeSessionTokenRequest(for session: Session) -> SessionTokenRequest {
    adoptStoredDeviceToken()
    let current = clerk?.client?.activeSessions.first { $0.id == session.id }
    return SessionTokenRequest(
      session: current ?? session,
      clientId: clerk?.client?.id,
      clientResponseGeneration: clientResponseGeneration,
      tokenGeneration: sessionTokenGeneration(sessionId: session.id),
      isCurrentActiveSession: current != nil
    )
  }

  func currentSession(for request: SessionTokenRequest) -> Session? {
    guard request.isCurrentActiveSession, isCurrent(request.tokenGeneration),
          request.clientResponseGeneration == clientResponseGeneration,
          let client = clerk?.client, client.id == request.clientId
    else { return nil }
    return client.activeSessions.first {
      $0.id == request.session.id
        && TokenFreshness.normalizedOrganizationId($0.lastActiveOrganizationId)
        == TokenFreshness.normalizedOrganizationId(request.session.lastActiveOrganizationId)
    }
  }

  func currentSessionToken(for request: SessionTokenRequest) -> TokenResource? {
    guard let session = currentSession(for: request),
          let token = session.lastActiveToken, tokenMatchesSession(token, session: session)
    else { return nil }
    return token
  }

  @discardableResult
  func updateSessionToken(_ token: TokenResource, for request: SessionTokenRequest) -> TokenResource? {
    guard let session = currentSession(for: request), tokenMatchesSession(token, session: session),
          let clerk, var client = clerk.client,
          let index = client.sessions.firstIndex(where: { $0.id == session.id })
    else { return nil }
    let freshest = acceptedSessionToken(token, previous: session, incomingSession: session)
    let wasReusable = canReuseSessionToken(sessionId: session.id)
    if freshest == token {
      invalidatedSessionTokens.remove(session.id)
    }
    let didChange = freshest != session.lastActiveToken
    if didChange {
      client.sessions[index].lastActiveToken = freshest
      applyClientWithoutIdentityChange(client)
    }
    if didChange || (!wasReusable && freshest == token) {
      clerk.auth.send(.tokenRefreshed(token: freshest.jwt))
    }
    return freshest
  }

  private func applyClientWithoutIdentityChange(_ client: Client) {
    if let store = clerk?.dependencies.identityStore, let currentDeviceToken {
      do {
        try store.saveClient(client, serverDate: lastServerDate, for: currentDeviceToken)
      } catch {
        ClerkLogger.logError(error, message: "Failed to cache the refreshed session token")
      }
    }
    clerk?.setClientFromIdentityController(client)
  }

  private func tokenMatchesSession(_ token: TokenResource, session: Session) -> Bool {
    guard let jwt = try? DecodedJWT(jwt: token.jwt), jwt.sessionId == session.id else { return false }
    return TokenFreshness.normalizedOrganizationId(jwt.organizationId)
      == TokenFreshness.normalizedOrganizationId(session.lastActiveOrganizationId)
  }

  private func acceptedSessionToken(_ token: TokenResource, previous: Session?, incomingSession: Session) -> TokenResource {
    let existing = previous?.lastActiveToken.flatMap {
      tokenMatchesSession($0, session: incomingSession) ? $0 : nil
    }
    return TokenFreshness.pickFreshest(existing: existing, incoming: token, tieBreaker: .incoming)
  }

  func reconcilingSessionTokens(
    in identity: ClerkIdentitySnapshot
  ) -> (identity: ClerkIdentitySnapshot, reusableSessionIds: Set<String>) {
    guard var incoming = identity.client else { return (identity, []) }
    var reusableSessionIds: Set<String> = []
    let current = identity.deviceToken == currentDeviceToken && clerk?.client?.id == incoming.id ? clerk?.client : nil
    for index in incoming.sessions.indices where incoming.sessions[index].status == .active {
      let session = incoming.sessions[index]
      let previous = current?.activeSessions.first { $0.id == session.id }
      guard let token = session.lastActiveToken, tokenMatchesSession(token, session: session) else { continue }
      let accepted = acceptedSessionToken(token, previous: previous, incomingSession: session)
      incoming.sessions[index].lastActiveToken = accepted
      if isNewlyAcceptedServerToken(accepted, incoming: token, previous: previous?.lastActiveToken) {
        reusableSessionIds.insert(session.id)
      }
    }
    return (
      ClerkIdentitySnapshot(state: identity.state, deviceToken: identity.deviceToken, client: incoming, serverDate: identity.serverDate),
      reusableSessionIds
    )
  }

  func prepareSessionTokensForIdentityChange(to identity: ClerkIdentitySnapshot) {
    if identity.deviceToken != currentDeviceToken || identity.client?.id != clerk?.client?.id {
      invalidateAllSessionTokens()
    } else {
      for previous in clerk?.client?.activeSessions ?? [] {
        let incoming = identity.client?.activeSessions.first { $0.id == previous.id }
        if tokenOwnershipChanged(from: previous, to: incoming) {
          invalidateSessionTokens(sessionId: previous.id)
        }
      }
    }
  }

  private func isNewlyAcceptedServerToken(
    _ accepted: TokenResource,
    incoming: TokenResource,
    previous: TokenResource?
  ) -> Bool {
    accepted == incoming && accepted != previous
  }

  private func tokenOwnershipChanged(from previous: Session, to incoming: Session?) -> Bool {
    guard let incoming else { return true }
    return TokenFreshness.normalizedOrganizationId(incoming.lastActiveOrganizationId)
      != TokenFreshness.normalizedOrganizationId(previous.lastActiveOrganizationId)
      || (previous.lastActiveToken != nil && incoming.lastActiveToken == nil)
  }
}
