//
//  Environment.swift
//
//
//  Created by Mike Pitre on 10/5/23.
//

import FactoryKit
import Foundation

extension Clerk {

    struct Environment: Codable, Sendable, Equatable {
        var authConfig: AuthConfig?
        var userSettings: UserSettings?
        var displayConfig: DisplayConfig?
        var fraudSettings: FraudSettings?
        var commerceSettings: CommerceSettings?

        var isEmpty: Bool {
            authConfig == nil && userSettings == nil && displayConfig == nil && fraudSettings == nil && commerceSettings == nil
        }
    }

}

extension Clerk.Environment {

    @MainActor
    static func get() async throws -> Clerk.Environment {
        try await Container.shared.environmentService().get()
    }

}

extension Clerk.Environment {

    static var mock: Self {
        .init(
            authConfig: .mock,
            userSettings: .mock,
            displayConfig: .mock,
            fraudSettings: nil,
            commerceSettings: .mock
        )
    }

}
