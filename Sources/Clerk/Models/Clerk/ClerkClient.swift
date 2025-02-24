//
//  ClerkClient.swift
//  Clerk
//
//  Created by Mike Pitre on 2/23/25.
//

import Dependencies
import DependenciesMacros
import Foundation
import SimpleKeychain

@DependencyClient
struct ClerkClient {
  var saveClientIdToKeychain: @Sendable (_ clientId: String) throws -> Void
  var signOut: @Sendable (_ sessionId: String?) async throws -> Void
  var setActive: @Sendable (_ sessionId: String) async throws -> Void
}

extension ClerkClient: DependencyKey, TestDependencyKey {
  static var liveValue: ClerkClient {
    @Dependency(\.apiClientProvider) var apiClientProvider
    
    return .init(
      saveClientIdToKeychain: { clientId in
        try? SimpleKeychain().set(clientId, forKey: "clientId")
      },
      signOut: { sessionId in
        if let sessionId {
          let request = ClerkFAPI.v1.client.sessions.id(sessionId).remove.post
          try await apiClientProvider.current().send(request)
        } else {
          let request = ClerkFAPI.v1.client.sessions.delete
          try await apiClientProvider.current().send(request)
        }
      },
      setActive: { sessionId in
        let request = ClerkFAPI.v1.client.sessions.id(sessionId).touch.post
        try await apiClientProvider.current().send(request)
      }
    )
  }
  
  static let testValue = Self(
    saveClientIdToKeychain: { _ in },
    signOut: unimplemented("ClerkClient.signOut"),
    setActive: unimplemented("ClerkClient.setActive")
  )
}

extension DependencyValues {
  var clerkClient: ClerkClient {
    get { self[ClerkClient.self] }
    set { self[ClerkClient.self] = newValue }
  }
}
