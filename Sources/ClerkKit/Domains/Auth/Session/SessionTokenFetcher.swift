//
//  SessionTokenFetcher.swift
//  Clerk
//

import Foundation

private struct SessionTokenFetchContext {
  let session: Session
  let cacheKey: String
  let sessionMinterEnabled: Bool
  let sessionSnapshotToken: TokenResource?
  let isCurrentActiveSession: Bool
}

@MainActor
private func makeSessionTokenFetchContext(
  session: Session,
  template: String?
) -> SessionTokenFetchContext {
  let currentSession = Clerk.shared.client?.activeSessions.first { $0.id == session.id }
  let resolvedSession = currentSession ?? session
  return SessionTokenFetchContext(
    session: resolvedSession,
    cacheKey: resolvedSession.tokenCacheKey(template: template),
    sessionMinterEnabled: Clerk.shared.environment?.authConfig.sessionMinter == true,
    sessionSnapshotToken: currentSession?.lastActiveToken,
    isCurrentActiveSession: currentSession != nil
  )
}

private func cacheLastActiveTokenIfNeeded(
  context: SessionTokenFetchContext,
  template: String?,
  generation: SessionTokensCache.Generation
) async {
  guard context.isCurrentActiveSession,
        template == nil,
        let lastActiveToken = context.sessionSnapshotToken,
        TokenFreshness.matches(
          lastActiveToken,
          sessionId: context.session.id,
          organizationId: context.session.lastActiveOrganizationId
        )
  else {
    return
  }

  await SessionTokensCache.shared.hydrate(
    lastActiveToken,
    cacheKey: context.cacheKey,
    generation: generation
  )
}

private func makeSessionTokenRequestParams(
  context: SessionTokenFetchContext,
  options: Session.GetTokenOptions
) async -> SessionTokenRequestParams? {
  guard options.template == nil else {
    return nil
  }

  let previousToken: TokenResource?
  if context.isCurrentActiveSession {
    let cachedToken = await SessionTokensCache.shared.getToken(cacheKey: context.cacheKey)
    previousToken = if let cachedToken {
      TokenFreshness.pickFreshest(
        existing: context.sessionSnapshotToken,
        incoming: cachedToken
      )
    } else {
      context.sessionSnapshotToken
    }
  } else {
    previousToken = nil
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

  struct InFlightTokenTask {
    let id: UUID
    let cacheGeneration: SessionTokensCache.Generation
    let isCurrentActiveSession: Bool
    let task: Task<TokenResource?, Error>
  }

  /// Key is `tokenCacheKey` property of a `session`
  var tokenTasks: [String: InFlightTokenTask] = [:]
  var forcedTokenTasks: [UUID: InFlightTokenTask] = [:]

  func reset() {
    for inFlightTask in tokenTasks.values {
      inFlightTask.task.cancel()
    }
    tokenTasks.removeAll()

    for inFlightTask in forcedTokenTasks.values {
      inFlightTask.task.cancel()
    }
    forcedTokenTasks.removeAll()
  }

  func getToken(_ session: Session, options: Session.GetTokenOptions = .init()) async throws -> TokenResource? {
    let cacheGeneration = await SessionTokensCache.shared.generation(
      sessionId: session.id
    )
    let runtime = try await Clerk.requireStableRuntime()
    let context = await makeSessionTokenFetchContext(session: session, template: options.template)

    if options.skipCache {
      return try await getForcedToken(
        context,
        options: options,
        runtime: runtime,
        cacheGeneration: cacheGeneration
      )
    }

    if let inProgressTask = tokenTasks[context.cacheKey] {
      if inProgressTask.cacheGeneration == cacheGeneration,
         inProgressTask.isCurrentActiveSession == context.isCurrentActiveSession
      {
        let result = await inProgressTask.task.result
        try runtime.validateStableRuntime()
        return try result.get()
      }

      inProgressTask.task.cancel()
    }

    let requestId = UUID()
    let task: Task<TokenResource?, Error> = Task {
      try Task.checkCancellation()
      return try await fetchToken(
        context,
        options: options,
        runtime: runtime,
        cacheGeneration: cacheGeneration
      )
    }

    tokenTasks[context.cacheKey] = InFlightTokenTask(
      id: requestId,
      cacheGeneration: cacheGeneration,
      isCurrentActiveSession: context.isCurrentActiveSession,
      task: task
    )

    let result = await task.result

    if tokenTasks[context.cacheKey]?.id == requestId {
      tokenTasks[context.cacheKey] = nil
    }

    try runtime.validateStableRuntime()
    return try result.get()
  }

  private func getForcedToken(
    _ context: SessionTokenFetchContext,
    options: Session.GetTokenOptions,
    runtime: ClerkRuntimeScope,
    cacheGeneration: SessionTokensCache.Generation
  ) async throws -> TokenResource? {
    let requestId = UUID()
    let task: Task<TokenResource?, Error> = Task {
      try Task.checkCancellation()
      return try await fetchToken(
        context,
        options: options,
        runtime: runtime,
        cacheGeneration: cacheGeneration
      )
    }
    forcedTokenTasks[requestId] = InFlightTokenTask(
      id: requestId,
      cacheGeneration: cacheGeneration,
      isCurrentActiveSession: context.isCurrentActiveSession,
      task: task
    )
    defer { forcedTokenTasks[requestId] = nil }

    let result = await withTaskCancellationHandler {
      await task.result
    } onCancel: {
      task.cancel()
    }

    try runtime.validateStableRuntime()
    return try result.get()
  }

  /**
   Internal function to get the session token. Checks the cache first.
   */
  @discardableResult @MainActor
  func fetchToken(_ session: Session, options: Session.GetTokenOptions = .init()) async throws -> TokenResource? {
    let cacheGeneration = await SessionTokensCache.shared.generation(
      sessionId: session.id
    )
    let runtime = try Clerk.requireStableRuntime()
    let context = makeSessionTokenFetchContext(session: session, template: options.template)
    return try await fetchToken(
      context,
      options: options,
      runtime: runtime,
      cacheGeneration: cacheGeneration
    )
  }

  @discardableResult @MainActor
  private func fetchToken(
    _ context: SessionTokenFetchContext,
    options: Session.GetTokenOptions,
    runtime: ClerkRuntimeScope,
    cacheGeneration: SessionTokensCache.Generation
  ) async throws -> TokenResource? {
    try Task.checkCancellation()
    try runtime.validateStableRuntime()

    await cacheLastActiveTokenIfNeeded(
      context: context,
      template: options.template,
      generation: cacheGeneration
    )

    if context.isCurrentActiveSession,
       options.skipCache == false,
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
        cacheKey: context.cacheKey,
        generation: cacheGeneration
      )
      try Task.checkCancellation()
      try runtime.validateStableRuntime()
      if storeResult?.didChangeCanonicalToken == true {
        Clerk.shared.auth.send(.tokenRefreshed(token: token.jwt))
      }
    }

    return token
  }
}

actor SessionTokensCache {
  static let shared = SessionTokensCache()

  struct Generation: Equatable {
    let sessionId: String
    let value: UInt64
  }

  struct StoreResult {
    let canonicalToken: TokenResource
    let didChangeCanonicalToken: Bool
  }

  private var cache: [String: TokenResource] = [:]
  private var generations: [String: UInt64] = [:]

  /// Returns a session token from the cache.
  /// - Parameter cacheKey: Cache key for a session's organization or token template.
  /// - Returns: ``TokenResource``
  func getToken(cacheKey: String) -> TokenResource? {
    cache[cacheKey]
  }

  /// Captures the current cache generation before a token request starts.
  func generation(sessionId: String) -> Generation {
    let value = generations[sessionId] ?? 0
    generations[sessionId] = value
    return Generation(sessionId: sessionId, value: value)
  }

  /// Reconciles a session snapshot without replacing an equally fresh canonical token.
  func hydrate(
    _ token: TokenResource,
    cacheKey: String,
    generation: Generation? = nil
  ) {
    if let generation, !isCurrent(generation) {
      return
    }

    let canonicalToken = TokenFreshness.pickFreshest(
      existing: cache[cacheKey],
      incoming: token,
      tieBreaker: .existing
    )
    cache[cacheKey] = canonicalToken
  }

  /// Atomically keeps the freshest token for a cache key.
  @discardableResult
  func storeIfFresher(
    _ token: TokenResource,
    cacheKey: String,
    now: Date = .now
  ) -> StoreResult {
    storeIfFresherUnchecked(token, cacheKey: cacheKey, now: now)
  }

  /// Atomically keeps the freshest token when the session has not been invalidated.
  func storeIfFresher(
    _ token: TokenResource,
    cacheKey: String,
    generation: Generation,
    now: Date = .now
  ) -> StoreResult? {
    guard isCurrent(generation) else {
      return nil
    }

    return storeIfFresherUnchecked(token, cacheKey: cacheKey, now: now)
  }

  private func storeIfFresherUnchecked(
    _ token: TokenResource,
    cacheKey: String,
    now: Date
  ) -> StoreResult {
    let previousToken = cache[cacheKey]
    let canonicalToken = TokenFreshness.pickFreshest(
      existing: previousToken,
      incoming: token,
      now: now
    )
    cache[cacheKey] = canonicalToken
    return StoreResult(
      canonicalToken: canonicalToken,
      didChangeCanonicalToken: previousToken?.jwt != canonicalToken.jwt
    )
  }

  /// Inserts a session token into the cache.
  /// - Parameters:
  ///   - token: ``TokenResource``
  ///   - cacheKey: Cache key for a session's organization or token template.
  func insertToken(_ token: TokenResource, cacheKey: String) {
    cache[cacheKey] = token
  }

  /// Removes every cached token for a session and invalidates earlier requests.
  func removeTokens(sessionId: String) {
    let cacheKeyPrefix = "\(sessionId)-"
    cache = cache.filter { key, _ in
      !key.hasPrefix(cacheKeyPrefix)
    }
    generations[sessionId] = (generations[sessionId] ?? 0) &+ 1
  }

  func clear() {
    cache.removeAll()
    generations = generations.mapValues { $0 &+ 1 }
  }

  private func isCurrent(_ generation: Generation) -> Bool {
    generations[generation.sessionId] ?? 0 == generation.value
  }
}
