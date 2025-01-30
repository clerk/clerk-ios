//
//  Environment.swift
//
//
//  Created by Mike Pitre on 10/5/23.
//

import Foundation
import Factory

extension Clerk {
    
    struct Environment: Codable, Sendable {
        var authConfig: AuthConfig?
        var displayConfig: DisplayConfig?
        var userSettings: UserSettings?
    }
    
}

extension Clerk.Environment {
    
    @discardableResult @MainActor
    static func get() async throws -> Clerk.Environment {
        let request = ClerkFAPI.v1.environment.get
        let environment = try await Clerk.shared.apiClient.send(request).value
        Clerk.shared.environment = environment
        return environment
    }
    
}
