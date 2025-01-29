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
    private var tokenTasks: [String: Task<TokenResource?, Error>] = [:]
    
    func getToken(_ session: Session, options: Session.GetTokenOptions = .init()) async throws -> TokenResource? {
        
        let cacheKey = session.tokenCacheKey(template: options.template)
        
        if let inProgressTask = tokenTasks[cacheKey] {
            return try await inProgressTask.value
        }
        
        let task: Task<TokenResource?, Error> = Task {
            return try await fetchToken(session, options: options)
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
           let token = Clerk.shared.sessionTokensByCacheKey[cacheKey],
           let expiresAt = token.decodedJWT?.expiresAt,
           Date.now.distance(to: expiresAt) > options.expirationBuffer
        {
            return token
        }
                    
        var token: TokenResource?
        
        let tokensRequest = ClerkFAPI.v1.client.sessions.id(session.id).tokens
        
        if let template = options.template {
            let templateTokenRequest = tokensRequest
                .template(template)
                .post()
            
            token = try await Clerk.shared.apiClient.send(templateTokenRequest).value
        } else {
            let defaultTokenRequest = tokensRequest.post()
            
            token = try await Clerk.shared.apiClient.send(defaultTokenRequest).value
        }
        
        if let token {
            Clerk.shared.sessionTokensByCacheKey[cacheKey] = token
        }
        
        return token
    }
    
}
