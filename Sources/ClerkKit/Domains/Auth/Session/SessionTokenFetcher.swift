import Foundation

actor SessionTokenFetcher {
  static let shared = SessionTokenFetcher()

  struct InFlightTokenTask {
    let id: UUID
    let tokenGeneration: ClerkIdentityController.SessionTokenGeneration
    let clientId: String?
    let clientResponseGeneration: ClientResponseGeneration
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

  func getToken(
    _ session: Session,
    options: Session.GetTokenOptions = .init(),
    onInFlightTaskShared: (@Sendable (UUID) -> Void)? = nil
  ) async throws -> TokenResource? {
    let runtime = try await Clerk.requireStableRuntime()
    let context = try await runtime.requireCurrentClerk().identityController.makeSessionTokenRequest(for: session)
    let tokenGeneration = context.tokenGeneration
    let cacheKey = context.session.tokenCacheKey(template: options.template)

    if options.skipCache {
      return try await getForcedToken(
        context,
        options: options,
        runtime: runtime
      )
    }

    if let inProgressTask = tokenTasks[cacheKey] {
      if inProgressTask.tokenGeneration == tokenGeneration,
         inProgressTask.clientId == context.clientId,
         inProgressTask.clientResponseGeneration == context.clientResponseGeneration,
         inProgressTask.isCurrentActiveSession == context.isCurrentActiveSession
      {
        // Lets concurrency tests observe reuse before the shared request is released.
        onInFlightTaskShared?(inProgressTask.id)
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
        runtime: runtime
      )
    }

    tokenTasks[cacheKey] = InFlightTokenTask(
      id: requestId,
      tokenGeneration: context.tokenGeneration,
      clientId: context.clientId,
      clientResponseGeneration: context.clientResponseGeneration,
      isCurrentActiveSession: context.isCurrentActiveSession,
      task: task
    )

    let result = await task.result

    if tokenTasks[cacheKey]?.id == requestId {
      tokenTasks[cacheKey] = nil
    }

    try runtime.validateStableRuntime()
    return try result.get()
  }

  private func getForcedToken(
    _ context: ClerkIdentityController.SessionTokenRequest,
    options: Session.GetTokenOptions,
    runtime: ClerkRuntimeScope
  ) async throws -> TokenResource? {
    let requestId = UUID()
    let task: Task<TokenResource?, Error> = Task {
      try Task.checkCancellation()
      return try await fetchToken(
        context,
        options: options,
        runtime: runtime
      )
    }
    forcedTokenTasks[requestId] = InFlightTokenTask(
      id: requestId,
      tokenGeneration: context.tokenGeneration,
      clientId: context.clientId,
      clientResponseGeneration: context.clientResponseGeneration,
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

  @discardableResult @MainActor
  func fetchToken(_ session: Session, options: Session.GetTokenOptions = .init()) async throws -> TokenResource? {
    let runtime = try Clerk.requireStableRuntime()
    let context = try runtime.requireCurrentClerk().identityController.makeSessionTokenRequest(for: session)
    return try await fetchToken(
      context,
      options: options,
      runtime: runtime
    )
  }

  @discardableResult @MainActor
  private func fetchToken(
    _ context: ClerkIdentityController.SessionTokenRequest,
    options: Session.GetTokenOptions,
    runtime: ClerkRuntimeScope
  ) async throws -> TokenResource? {
    try Task.checkCancellation()
    try runtime.validateStableRuntime()

    let clerk = try runtime.requireCurrentClerk()
    let controller = clerk.identityController
    let cacheKey = context.session.tokenCacheKey(template: options.template)
    let currentSession = controller.currentSession(for: context)
    let defaultToken = controller.currentSessionToken(for: context)
    let canReuseDefault = controller.canReuseSessionToken(sessionId: context.session.id)
    let cachedToken = if options.template != nil {
      currentSession == nil ? nil : SessionTemplateTokensCache.shared.getToken(cacheKey: cacheKey)
    } else {
      canReuseDefault ? defaultToken : nil
    }
    if !options.skipCache, let token = cachedToken,
       let expiresAt = token.decodedJWT?.expiresAt,
       Date.now.distance(to: expiresAt) > options.expirationBuffer
    {
      return token
    }

    let minterEnabled = clerk.environment?.authConfig.sessionMinter == true
    let requestParams = options.template == nil ? SessionTokenRequestParams(
      organizationId: context.session.lastActiveOrganizationId ?? "",
      token: minterEnabled ? defaultToken?.jwt : nil,
      forceOrigin: minterEnabled && (options.skipCache || !canReuseDefault) ? "true" : nil
    ) : nil
    let token = try await clerk.dependencies.sessionService.fetchToken(
      sessionId: context.session.id,
      template: options.template,
      params: requestParams
    )
    try Task.checkCancellation()
    try runtime.validateStableRuntime()
    guard let token else { return nil }
    controller.adoptStoredDeviceToken()
    if options.template != nil {
      if controller.currentSession(for: context) != nil {
        let stored = SessionTemplateTokensCache.shared.storeIfFresher(token, cacheKey: cacheKey)
        if stored.didChangeCanonicalToken {
          clerk.auth.send(.tokenRefreshed(token: stored.canonicalToken.jwt))
        }
        return stored.canonicalToken
      }
    } else if let accepted = controller.updateSessionToken(token, for: context) {
      return accepted
    }
    return token
  }
}

@MainActor
final class SessionTemplateTokensCache {
  static let shared = SessionTemplateTokensCache()

  struct StoreResult {
    let canonicalToken: TokenResource
    let didChangeCanonicalToken: Bool
  }

  private var templateTokens: [String: TokenResource] = [:]

  func getToken(cacheKey: String) -> TokenResource? {
    templateTokens[cacheKey]
  }

  @discardableResult
  func storeIfFresher(_ token: TokenResource, cacheKey: String, now: Date = .now) -> StoreResult {
    let previous = templateTokens[cacheKey]
    let canonical = TokenFreshness.pickFreshest(existing: previous, incoming: token, now: now)
    templateTokens[cacheKey] = canonical
    return StoreResult(canonicalToken: canonical, didChangeCanonicalToken: previous?.jwt != canonical.jwt)
  }

  func insertToken(_ token: TokenResource, cacheKey: String) {
    templateTokens[cacheKey] = token
  }

  func removeTokens(sessionId: String) {
    templateTokens = templateTokens.filter { !$0.key.hasPrefix("\(sessionId)-") }
  }

  func clear() {
    templateTokens.removeAll()
  }
}
