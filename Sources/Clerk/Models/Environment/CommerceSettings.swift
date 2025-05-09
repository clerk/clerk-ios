//
//  CommerceSettings.swift
//  Clerk
//
//  Created by Mike Pitre on 5/9/25.
//

import Foundation

struct CommerceSettings: Codable, Sendable {
  let billing: Billing

  struct Billing: Codable, Sendable {
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
