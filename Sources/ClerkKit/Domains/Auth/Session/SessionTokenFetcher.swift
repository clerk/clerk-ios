//
//  SessionTokenFetcher.swift
//  Clerk
//

import Foundation

/// The purpose of this actor is to NOT trigger refreshes of tokens if a refresh is already in progress.
/// This is not a token cache. It is only responsible to returning in progress tasks to refresh a token.
actor SessionTokenFetcher {
  static let shared = SessionTokenFetcher()

  /// A forced request gets its own key so a `skipCache` caller never joins a task that
  /// is allowed to answer from a cache. Typed rather than a delimited string so no
  /// template name can collide with the force marker.
  private struct TokenTaskKey: Hashable {
    let cacheKey: String
    let force: Bool
  }

  private var tokenTasks: [TokenTaskKey: Task<TokenResource?, Error>] = [:]

  func reset() {
    for task in tokenTasks.values {
      task.cancel()
    }
    tokenTasks.removeAll()
  }

  private func taskKey(_ session: Session, options: Session.GetTokenOptions) -> TokenTaskKey {
    TokenTaskKey(cacheKey: session.tokenCacheKey(template: options.template), force: options.skipCache)
  }

  func getToken(_ session: Session, options: Session.GetTokenOptions = .init()) async throws -> TokenResource? {
    let runtime = try await Clerk.requireStableRuntime()
    let taskKey = taskKey(session, options: options)

    if let inProgressTask = tokenTasks[taskKey] {
      let result = await inProgressTask.result
      try runtime.validateStableRuntime()
      return try result.get()
    }

    let task: Task<TokenResource?, Error> = Task {
      try Task.checkCancellation()
      return try await fetchToken(session, options: options, runtime: runtime)
    }

    tokenTasks[taskKey] = task

    let result = await task.result

    // clear the inProgressTask on success AND failure
    tokenTasks[taskKey] = nil

    try runtime.validateStableRuntime()
    return try result.get()
  }

  /**
   Internal function to get the session token. Checks the cache first.
   */
  @discardableResult @MainActor
  func fetchToken(_ session: Session, options: Session.GetTokenOptions = .init()) async throws -> TokenResource? {
    let runtime = try Clerk.requireStableRuntime()
    return try await fetchToken(session, options: options, runtime: runtime)
  }

  @discardableResult @MainActor
  private func fetchToken(
    _ session: Session,
    options: Session.GetTokenOptions,
    runtime: ClerkRuntimeScope
  ) async throws -> TokenResource? {
    let cacheKey = session.tokenCacheKey(template: options.template)

    try Task.checkCancellation()
    try runtime.validateStableRuntime()

    if options.skipCache == false,
       let token = await SessionTokensCache.shared.getToken(cacheKey: cacheKey),
       let expiresAt = token.decodedJWT?.expiresAt,
       Date.now.distance(to: expiresAt) > options.expirationBuffer
    {
      try Task.checkCancellation()
      try runtime.validateStableRuntime()
      return token
    }

    try Task.checkCancellation()
    try runtime.validateStableRuntime()

    let cacheGeneration = await SessionTokensCache.shared.generation(sessionId: session.id)

    let token = try await Clerk.shared.dependencies.sessionService.fetchToken(
      sessionId: session.id,
      template: options.template,
      skipCache: options.skipCache
    )

    try Task.checkCancellation()
    try runtime.validateStableRuntime()

    if let token {
      try Task.checkCancellation()
      try runtime.validateStableRuntime()
      await SessionTokensCache.shared.insertToken(token, cacheKey: cacheKey, generation: cacheGeneration)
      try Task.checkCancellation()
      try runtime.validateStableRuntime()
      Clerk.shared.auth.send(.tokenRefreshed(token: token.jwt))
    }

    return token
  }
}

/// Fence taken before a token request so a request that started before an invalidation
/// cannot write its result back afterwards.
struct SessionTokensCacheGeneration: Equatable {
  let sessionId: String
  let value: Int
}

actor SessionTokensCache {
  static let shared = SessionTokensCache()

  private var cache: [String: TokenResource] = [:]
  private var generations: [String: Int] = [:]

  /// Returns a session token from the cache.
  /// - Parameter cacheKey: cacheKey is the session id + template name if there is one.
  ///                       For example, `sess_abc12345` or `sess_abc12345-supabase`.
  /// - Returns: ``TokenResource``
  func getToken(cacheKey: String) -> TokenResource? {
    cache[cacheKey]
  }

  /// The current cache generation for a session. Capture it before a token request and
  /// pass it back to ``insertToken(_:cacheKey:generation:)``.
  func generation(sessionId: String) -> SessionTokensCacheGeneration {
    let value = generations[sessionId] ?? 0
    generations[sessionId] = value
    return .init(sessionId: sessionId, value: value)
  }

  /// Inserts a session token into the cache, keeping whichever token is fresher.
  /// - Parameters:
  ///   - token: ``TokenResource``
  ///   - cacheKey: cacheKey is the session id + template name if there is one.
  ///               For example, `sess_abc12345` or `sess_abc12345-supabase`.
  ///   - generation: The generation captured before the request. The write is dropped when
  ///                 the session's tokens were invalidated while the request was in flight.
  func insertToken(_ token: TokenResource, cacheKey: String, generation: SessionTokensCacheGeneration? = nil) {
    if let generation, generations[generation.sessionId] ?? 0 != generation.value {
      return
    }

    cache[cacheKey] = freshestToken(existing: cache[cacheKey], incoming: token)
  }

  /// Removes every cached token for a session, including its template tokens.
  /// - Parameter sessionId: The session whose tokens are no longer valid.
  func removeTokens(sessionId: String) {
    let defaultCacheKey = Session.tokenCacheKey(sessionId: sessionId, template: nil)
    cache = cache.filter { key, _ in
      key != defaultCacheKey && !key.hasPrefix("\(defaultCacheKey)-")
    }
    generations[sessionId] = (generations[sessionId] ?? 0) + 1
  }

  func clear() {
    cache.removeAll()
    for sessionId in generations.keys {
      generations[sessionId] = (generations[sessionId] ?? 0) + 1
    }
  }
}

/// Picks the fresher of two tokens.
///
/// Origin-minted tokens carry an `oiat` (origin-issued-at) JWT header, the time the claims
/// were last assembled. Minted tokens inherit the `oiat` of the token they were minted from,
/// so an equal `oiat` is broken by `iat`. A token without an `oiat` predates the feature and
/// loses to one that has it. Ties return the incoming token: identical timestamps can still
/// mean different claims.
func freshestToken(existing: TokenResource?, incoming: TokenResource) -> TokenResource {
  guard let existing else {
    return incoming
  }

  let existingOiat = existing.decodedJWT?.originIssuedAt
  let incomingOiat = incoming.decodedJWT?.originIssuedAt

  switch (existingOiat, incomingOiat) {
  case (nil, nil):
    return incoming
  case (.some, nil):
    return existing
  case (nil, .some):
    return incoming
  case let (.some(existingOiat), .some(incomingOiat)):
    if existingOiat > incomingOiat {
      return existing
    }
    if existingOiat < incomingOiat {
      return incoming
    }

    let existingIssuedAt = existing.decodedJWT?.issuedAt ?? .distantPast
    let incomingIssuedAt = incoming.decodedJWT?.issuedAt ?? .distantPast
    return existingIssuedAt > incomingIssuedAt ? existing : incoming
  }
}

extension DecodedJWT {
  /// Value of the `oiat` protected header, if available.
  var originIssuedAt: Double? {
    switch header["oiat"] {
    case let value as Double:
      value
    case let value as Int:
      Double(value)
    case let value as String:
      Double(value)
    default:
      nil
    }
  }
}
