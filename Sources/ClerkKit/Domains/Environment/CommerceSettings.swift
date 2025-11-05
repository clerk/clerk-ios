//
//  CommerceSettings.swift
//  Clerk
//
//  Created by Mike Pitre on 5/9/25.
//

import Foundation

public struct CommerceSettings: Codable, Sendable, Equatable {
  public var billing: Billing

  public struct Billing: Codable, Sendable, Equatable {
    public var enabled: Bool
    public var hasPaidUserPlans: Bool
    public var hasPaidOrgPlans: Bool
  }
}

