//
//  SessionTokenFetcher.swift
//  Clerk
//

import Foundation

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
    let cacheKey = session.tokenCacheKey(template: options.template)

    if let inProgressTask = tokenTasks[cacheKey] {
      let result = await inProgressTask.result
      try runtime.validateStableRuntime()
      return try result.get()
    }

    let task: Task<TokenResource?, Error> = Task {
      try Task.checkCancellation()
      return try await fetchToken(session, options: options, runtime: runtime)
    }

    tokenTasks[cacheKey] = task

    let result = await task.result

    // clear the inProgressTask on success AND failure
    tokenTasks[cacheKey] = nil

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

    let token = try await Clerk.shared.dependencies.sessionService.fetchToken(
      sessionId: session.id,
      template: options.template
    )

    try Task.checkCancellation()
    try runtime.validateStableRuntime()

    if let token {
      try Task.checkCancellation()
      try runtime.validateStableRuntime()
      await SessionTokensCache.shared.insertToken(token, cacheKey: cacheKey)
      try Task.checkCancellation()
      try runtime.validateStableRuntime()
      Clerk.shared.auth.send(.tokenRefreshed(token: token.jwt))
    }

    return token
  }
}

actor SessionTokensCache {
  static let shared = SessionTokensCache()

  private var cache: [String: TokenResource] = [:]

  /// Returns a session token from the cache.
  /// - Parameter cacheKey: cacheKey is the session id + template name if there is one.
  ///                       For example, `sess_abc12345` or `sess_abc12345-supabase`.
  /// - Returns: ``TokenResource``
  func getToken(cacheKey: String) -> TokenResource? {
    cache[cacheKey]
  }

  /// Inserts a session token into the cache.
  /// - Parameters:
  ///   - token: ``TokenResource``
  ///   - cacheKey: cacheKey is the session id + template name if there is one.
  ///               For example, `sess_abc12345` or `sess_abc12345-supabase`.
  func insertToken(_ token: TokenResource, cacheKey: String) {
    cache[cacheKey] = token
  }

  func clear() {
    cache.removeAll()
  }
}
