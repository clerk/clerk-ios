//
//  ClerkService.swift
//  Clerk
//
//  Created by Mike Pitre on 2/26/25.
//

import Factory
import Foundation
import Get

struct ClerkService {
  var saveClientToKeychain: (_ client: Client) throws -> Void
  var loadClientFromKeychain: () throws -> Client?
  var saveEnvironmentToKeychain: (_ environment: Clerk.Environment) throws -> Void
  var loadEnvironmentFromKeychain: () throws -> Clerk.Environment?
  var signOut: (_ sessionId: String?) async throws -> Void
  var setActive: (_ sessionId: String, _ organizationId: String?) async throws -> Void
}

extension ClerkService {

  static var liveValue: Self {
    .init(
      saveClientToKeychain: { client in
        let encoder = JSONEncoder.clerkEncoder
        let clientData = try encoder.encode(client)
        try Container.shared.keychain().set(clientData, forKey: "cachedClient")
      },
      loadClientFromKeychain: {
        guard let clientData = try? Container.shared.keychain().data(forKey: "cachedClient") else {
          return nil
        }
        let decoder = JSONDecoder.clerkDecoder
        return try decoder.decode(Client.self, from: clientData)
      },
      saveEnvironmentToKeychain: { environment in
        let encoder = JSONEncoder.clerkEncoder
        let environmentData = try encoder.encode(environment)
        try Container.shared.keychain().set(environmentData, forKey: "cachedEnvironment")
      },
      loadEnvironmentFromKeychain: {
        guard let environmentData = try? Container.shared.keychain().data(forKey: "cachedEnvironment") else {
          return nil
        }
        let decoder = JSONDecoder.clerkDecoder
        return try decoder.decode(Clerk.Environment.self, from: environmentData)
      },
      signOut: { sessionId in
        if let sessionId {
          let request = ClerkFAPI.v1.client.sessions.id(sessionId).remove.post
          try await Container.shared.apiClient().send(request)
        } else {
          let request = ClerkFAPI.v1.client.sessions.delete
          try await Container.shared.apiClient().send(request)
        }
      },
      setActive: { sessionId, organizationId in
        let request = Request<ClientResponse<Session>>(
          path: "v1/client/sessions/\(sessionId)/touch",
          method: .post,
          body: ["active_organization_id": organizationId ?? ""]  // nil key/values get dropped, use an empty string to set no active org
        )
        try await Container.shared.apiClient().send(request)
      }
    )
  }

}

extension Container {

  var clerkService: Factory<ClerkService> {
    self { .liveValue }
  }

}
