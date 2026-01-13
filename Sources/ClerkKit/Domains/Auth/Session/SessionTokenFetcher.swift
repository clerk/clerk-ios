//
//  SessionTokenFetcher.swift
//  Clerk
//
//  Created by Mike Pitre on 1/19/25.
//

import Foundation

// The purpose of this actor is to NOT trigger refreshes of tokens if a refresh is already in progress.
// This is not a token cache. It is only responsible to returning in progress tasks to refresh a token.
actor SessionTokenFetcher {
  static let shared = SessionTokenFetcher()

  // Key is `tokenCacheKey` property of a `session`
  var tokenTasks: [String: Task<TokenResource?, Error>] = [:]

  func getToken(_ session: Session, options: Session.GetTokenOptions = .init()) async throws -> TokenResource? {
    let cacheKey = session.tokenCacheKey(template: options.template)

    if let inProgressTask = tokenTasks[cacheKey] {
      return try await inProgressTask.value
    }

    let task: Task<TokenResource?, Error> = Task {
      try await fetchToken(session, options: options)
    }

    tokenTasks[cacheKey] = task

    let result = await task.result

    // clear the inProgressTask on success AND failure
    tokenTasks[cacheKey] = nil

    return try result.get()
  }

  /**
   Internal function to get the session token. Checks the cache first.
   */
  @discardableResult @MainActor
  func fetchToken(_ session: Session, options: Session.GetTokenOptions = .init()) async throws -> TokenResource? {
    let cacheKey = session.tokenCacheKey(template: options.template)

    if options.skipCache == false,
       let token = await SessionTokensCache.shared.getToken(cacheKey: cacheKey),
       let expiresAt = token.decodedJWT?.expiresAt,
       Date.now.distance(to: expiresAt) > options.expirationBuffer
    {
      return token
    }

    let token = try await Clerk.shared.dependencies.sessionService.fetchToken(
      sessionId: session.id,
      template: options.template
    )

    if let token {
      await SessionTokensCache.shared.insertToken(token, cacheKey: cacheKey)
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
}
