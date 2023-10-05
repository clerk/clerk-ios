//
//  Environment.swift
//
//
//  Created by Mike Pitre on 10/5/23.
//

import Foundation

public struct ClerkEnvironment: Decodable {
    static var shared = ClerkEnvironment()
}

extension ClerkEnvironment {
    
    static func get() async throws {
        let request = APIEndpoint
            .v1
            .environment
            .get
        
        shared = try await Clerk.apiClient.send(request).value
    }
    
}
