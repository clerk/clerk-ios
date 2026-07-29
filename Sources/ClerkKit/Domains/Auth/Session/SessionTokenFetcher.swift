//
//  SessionTokenFetcher.swift
//  Clerk
//

import Foundation

private struct SessionTokenFetchContext {
  let session: Session
  let cacheKey: String
  let sessionMinterEnabled: Bool
}

@MainActor
private func makeSessionTokenFetchContext(
  session: Session,
  template: String?
) -> SessionTokenFetchContext {
  let currentSession = Clerk.shared.client?.sessions.first { $0.id == session.id } ?? session
  return SessionTokenFetchContext(
    session: currentSession,
    cacheKey: currentSession.tokenCacheKey(template: template),
    sessionMinterEnabled: Clerk.shared.environment?.authConfig.sessionMinter == true
  )
}

private func cacheLastActiveTokenIfNeeded(
  context: SessionTokenFetchContext,
  template: String?
) async {
  guard template == nil,
        let lastActiveToken = context.session.lastActiveToken,
        TokenFreshness.matches(
          lastActiveToken,
          sessionId: context.session.id,
          organizationId: context.session.lastActiveOrganizationId
        )
  else {
    return
  }

  await SessionTokensCache.shared.storeIfFresher(
    lastActiveToken,
    cacheKey: context.cacheKey
  )
}

private func makeSessionTokenRequestParams(
  context: SessionTokenFetchContext,
  options: Session.GetTokenOptions
) async -> SessionTokenRequestParams? {
  guard options.template == nil else {
    return nil
  }

  let cachedToken = await SessionTokensCache.shared.getToken(cacheKey: context.cacheKey)
  let previousToken = if let cachedToken {
    TokenFreshness.pickFreshest(
      existing: context.session.lastActiveToken,
      incoming: cachedToken
    )
  } else {
    context.session.lastActiveToken
  }

  return SessionTokenRequestParams(
    organizationId: context.session.lastActiveOrganizationId ?? "",
    token: context.sessionMinterEnabled ? previousToken?.jwt : nil,
    forceOrigin: context.sessionMinterEnabled && options.skipCache ? "true" : nil
  )
}

/// The purpose of this actor is to NOT trigger refreshes of tokens if a refresh is already in progress.
/// This is not a token cache. It is only responsible to returning in progress tasks to refresh a token.
actor SessionTokenFetcher {
  static let shared = SessionTokenFetcher()

  /// Key is `tokenCacheKey` property of a `session`
  var tokenTasks: [String: Task<TokenResource?, Error>] = [:]

  func reset() {
    for task in tokenTasks.values {
      task.cancel()
    }
    tokenTasks.removeAll()
  }

  func getToken(_ session: Session, options: Session.GetTokenOptions = .init()) async throws -> TokenResource? {
    let runtime = try await Clerk.requireStableRuntime()
    let context = await makeSessionTokenFetchContext(session: session, template: options.template)

    if options.skipCache {
      let token = try await fetchToken(context, options: options, runtime: runtime)
      try runtime.validateStableRuntime()
      return token
    }

    if let inProgressTask = tokenTasks[context.cacheKey] {
      let result = await inProgressTask.result
      try runtime.validateStableRuntime()
      return try result.get()
    }

    let task: Task<TokenResource?, Error> = Task {
      try Task.checkCancellation()
      return try await fetchToken(context, options: options, runtime: runtime)
    }

    tokenTasks[context.cacheKey] = task

    let result = await task.result

    // clear the inProgressTask on success AND failure
    tokenTasks[context.cacheKey] = nil

    try runtime.validateStableRuntime()
    return try result.get()
  }

  /**
   Internal function to get the session token. Checks the cache first.
   */
  @discardableResult @MainActor
  func fetchToken(_ session: Session, options: Session.GetTokenOptions = .init()) async throws -> TokenResource? {
    let runtime = try Clerk.requireStableRuntime()
    let context = makeSessionTokenFetchContext(session: session, template: options.template)
    return try await fetchToken(context, options: options, runtime: runtime)
  }

  @discardableResult @MainActor
  private func fetchToken(
    _ context: SessionTokenFetchContext,
    options: Session.GetTokenOptions,
    runtime: ClerkRuntimeScope
  ) async throws -> TokenResource? {
    try Task.checkCancellation()
    try runtime.validateStableRuntime()

    await cacheLastActiveTokenIfNeeded(
      context: context,
      template: options.template
    )

    if options.skipCache == false,
       let token = await SessionTokensCache.shared.getToken(cacheKey: context.cacheKey),
       let expiresAt = token.decodedJWT?.expiresAt,
       Date.now.distance(to: expiresAt) > options.expirationBuffer
    {
      try Task.checkCancellation()
      try runtime.validateStableRuntime()
      return token
    }

    try Task.checkCancellation()
    try runtime.validateStableRuntime()

    let requestParams = await makeSessionTokenRequestParams(
      context: context,
      options: options
    )

    try Task.checkCancellation()
    try runtime.validateStableRuntime()

    let token = try await Clerk.shared.dependencies.sessionService.fetchToken(
      sessionId: context.session.id,
      template: options.template,
      params: requestParams
    )

    try Task.checkCancellation()
    try runtime.validateStableRuntime()

    if let token {
      try Task.checkCancellation()
      try runtime.validateStableRuntime()
      let storeResult = await SessionTokensCache.shared.storeIfFresher(
        token,
        cacheKey: context.cacheKey
      )
      try Task.checkCancellation()
      try runtime.validateStableRuntime()
      if storeResult.didStoreIncoming {
        Clerk.shared.auth.send(.tokenRefreshed(token: token.jwt))
      }
    }

    return token
  }
}

actor SessionTokensCache {
  static let shared = SessionTokensCache()

  struct StoreResult {
    let canonicalToken: TokenResource
    let didStoreIncoming: Bool
  }

  private var cache: [String: TokenResource] = [:]

  /// Returns a session token from the cache.
  /// - Parameter cacheKey: Cache key for a session's organization or token template.
  /// - Returns: ``TokenResource``
  func getToken(cacheKey: String) -> TokenResource? {
    cache[cacheKey]
  }

  /// Atomically keeps the freshest token for a cache key.
  @discardableResult
  func storeIfFresher(
    _ token: TokenResource,
    cacheKey: String,
    now: Date = .now
  ) -> StoreResult {
    let canonicalToken = TokenFreshness.pickFreshest(
      existing: cache[cacheKey],
      incoming: token,
      now: now
    )
    cache[cacheKey] = canonicalToken
    return StoreResult(
      canonicalToken: canonicalToken,
      didStoreIncoming: canonicalToken.jwt == token.jwt
    )
  }

  /// Inserts a session token into the cache.
  /// - Parameters:
  ///   - token: ``TokenResource``
  ///   - cacheKey: Cache key for a session's organization or token template.
  func insertToken(_ token: TokenResource, cacheKey: String) {
    cache[cacheKey] = token
  }

  func clear() {
    cache.removeAll()
  }
}
