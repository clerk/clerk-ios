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
        self { ClerkService() }
    }

}

struct ClerkService {

    var signOut: @MainActor (_ sessionId: String?) async throws -> Void = { sessionId in
        if let sessionId {
            let request = Request<EmptyResponse>(
                path: "/v1/client/sessions/\(sessionId)/remove",
                method: .post
            )
            
            try await Container.shared.apiClient().send(request)
        } else {
            let request = Request<EmptyResponse>(
                path: "/v1/client/sessions",
                method: .delete
            )
            
            try await Container.shared.apiClient().send(request)
        }
    }

    var setActive: @MainActor (_ sessionId: String, _ organizationId: String?) async throws -> Void = { sessionId, organizationId in
        let request = Request<EmptyResponse>(
            path: "/v1/client/sessions/\(sessionId)/touch",
            method: .post,
            body: ["active_organization_id": organizationId ?? ""]
        )
        
        try await Container.shared.apiClient().send(request)
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
