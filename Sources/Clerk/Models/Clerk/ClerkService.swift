//
//  ClerkService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import FactoryKit
import Foundation

extension Container {
  
  var clerkService: Factory<ClerkService> {
    self { @MainActor in ClerkService() }
  }
  
}

@MainActor
struct ClerkService {
  
  var signOut: (_ sessionId: String?) async throws -> Void = { sessionId in
    if let sessionId {
      _ = try await Container.shared.apiClient().request()
        .add(path: "/v1/client/sessions/\(sessionId)/remove")
        .method(.post)
        .data(type: ClientResponse<Session>.self)
        .async()
    } else {
      _ = try await Container.shared.apiClient().request()
        .add(path: "/v1/client/sessions")
        .method(.delete)
        .data(type: ClientResponse<Client>.self)
        .async()
    }
  }
  
  var setActive: (_ sessionId: String, _ organizationId: String?) async throws -> Void = { sessionId, organizationId in
    _ = try await Container.shared.apiClient().request()
      .add(path: "/v1/client/sessions/\(sessionId)/touch")
      .method(.post)
      .body(formEncode: ["active_organization_id": organizationId])
      .data(type: ClientResponse<Session>.self)
      .async()
  }
  
  // MARK: - Keychain Utilities
  
  var saveClientToKeychain: (_ client: Client) throws -> Void = { client in
    let clientData = try JSONEncoder.clerkEncoder.encode(client)
    try Container.shared.keychain().set(clientData, forKey: "cachedClient")
  }
  
  var loadClientFromKeychain: () throws -> Client? = {
    guard let clientData = try? Container.shared.keychain().data(forKey: "cachedClient") else {
      return nil
    }
    let decoder = JSONDecoder.clerkDecoder
    return try decoder.decode(Client.self, from: clientData)
  }
  
  var saveEnvironmentToKeychain: (_ environment: Clerk.Environment) throws -> Void = { environment in
    let encoder = JSONEncoder.clerkEncoder
    let environmentData = try encoder.encode(environment)
    try Container.shared.keychain().set(environmentData, forKey: "cachedEnvironment")
  }
  
  var loadEnvironmentFromKeychain: () throws -> Clerk.Environment? = {
    guard let environmentData = try? Container.shared.keychain().data(forKey: "cachedEnvironment") else {
      return nil
    }
    let decoder = JSONDecoder.clerkDecoder
    return try decoder.decode(Clerk.Environment.self, from: environmentData)
  }
  
}
