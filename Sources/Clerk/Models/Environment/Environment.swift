//
//  Environment.swift
//
//
//  Created by Mike Pitre on 10/5/23.
//

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
        let request = Request<Clerk.Environment>.build(path: "/v1/environment")
        let environment = try await Clerk.shared.dependencyContainer.apiClient.send(request).value
        Clerk.shared.environment = environment
        return environment
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
