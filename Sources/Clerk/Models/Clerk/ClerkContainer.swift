//
//  ClerkContainer.swift
//  Clerk
//
//  Created by Mike Pitre on 2/23/25.
//

import Factory
import Foundation
import SimpleKeychain

final class ClerkContainer: SharedContainer {
  public static let shared = ClerkContainer()
  public let manager = ContainerManager()
  
  var saveClientIdToKeychain: Factory<(_ clientId: String) throws -> Void> {
    self {{ clientId in
      try SimpleKeychain().set(clientId, forKey: "clientId")
    }}
  }
  
  var signOut: Factory<(_ sessionId: String?) async throws -> Void> {
    self {{ sessionId in
      if let sessionId {
        let request = ClerkFAPI.v1.client.sessions.id(sessionId).remove.post
        try await Clerk.shared.apiClient.send(request)
      } else {
        let request = ClerkFAPI.v1.client.sessions.delete
        try await Clerk.shared.apiClient.send(request)
      }
    }}
  }
  
  var setActive: Factory<(_ sessionId: String) async throws -> Void> {
    self {{ sessionId in
      let request = ClerkFAPI.v1.client.sessions.id(sessionId).touch.post
      try await Clerk.shared.apiClient.send(request)
    }}
  }
  
}
