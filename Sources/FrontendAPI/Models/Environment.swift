//
//  Environment.swift
//
//
//  Created by Mike Pitre on 10/5/23.
//

import Foundation

extension Clerk {
 
    public struct Environment: Decodable {
        
    }
    
}

extension Clerk.Environment {
    
    @MainActor
    public func get() async throws {
        let request = APIEndpoint
            .v1
            .environment
            .get
        
        Clerk.shared.environment = try await Clerk.apiClient.send(request).value
    }
    
}
