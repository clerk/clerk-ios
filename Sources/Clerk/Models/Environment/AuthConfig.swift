//
//  AuthConfig.swift
//  Clerk
//
//  Created by Mike Pitre on 8/2/24.
//

import Foundation

extension Clerk.Environment {

    struct AuthConfig: Codable, Sendable, Equatable {
        let singleSessionMode: Bool
    }

}

extension Clerk.Environment.AuthConfig {

    static var mock: Self {
        .init(
            singleSessionMode: false
        )
    }

}
