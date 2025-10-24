//
//  Environment.swift
//
//
//  Created by Mike Pitre on 10/5/23.
//

import FactoryKit
import Foundation

extension Clerk {

    public struct Environment: Codable, Sendable, Equatable {
        public var authConfig: AuthConfig?
        public var userSettings: UserSettings?
        public var displayConfig: DisplayConfig?
        public var fraudSettings: FraudSettings?
        public var commerceSettings: CommerceSettings?

        public var isEmpty: Bool {
            authConfig == nil && userSettings == nil && displayConfig == nil && fraudSettings == nil && commerceSettings == nil
        }
    }

}

extension Clerk.Environment {

    @MainActor
    public static func get() async throws -> Clerk.Environment {
        try await Container.shared.environmentService().get()
    }

}

extension Clerk.Environment {

    package static var mock: Self {
        .init(
            authConfig: .mock,
            userSettings: .mock,
            displayConfig: .mock,
            fraudSettings: nil,
            commerceSettings: .mock
        )
    }

}
