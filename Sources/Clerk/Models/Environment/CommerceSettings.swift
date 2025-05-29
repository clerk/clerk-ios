//
//  CommerceSettings.swift
//  Clerk
//
//  Created by Mike Pitre on 5/9/25.
//

import Foundation

struct CommerceSettings: Codable, Sendable, Equatable {
  let billing: Billing

  struct Billing: Codable, Sendable, Equatable {
    let enabled: Bool
    let hasPaidUserPlans: Bool
    let hasPaidOrgPlans: Bool
  }
}

extension CommerceSettings {

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
