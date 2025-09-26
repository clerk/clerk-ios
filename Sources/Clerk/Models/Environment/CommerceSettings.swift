//
//  CommerceSettings.swift
//  Clerk
//
//  Created by Mike Pitre on 5/9/25.
//

import Foundation

public struct CommerceSettings: Codable, Sendable, Equatable {
    public let billing: Billing

    public struct Billing: Codable, Sendable, Equatable {
        public let enabled: Bool
        let hasPaidUserPlans: Bool
        let hasPaidOrgPlans: Bool
    }
}

@_spi(Internal)
public extension CommerceSettings {

    static var mock: Self {
        .init(
            billing: .init(
                enabled: true,
                hasPaidUserPlans: true,
                hasPaidOrgPlans: true
            )
        )
    }

}
