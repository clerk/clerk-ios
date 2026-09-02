//
//  BillingPlan.swift
//  Clerk
//

import Foundation

public enum BillingPayerResourceType: String, Codable, Equatable, Sendable {
  case org
  case user
}

public struct BillingPlanUnitPriceTier: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var startsAtBlock: Int
  public var endsAfterBlock: Int?
  public var feePerBlock: BillingMoneyAmount

  public init(
    id: String,
    startsAtBlock: Int,
    endsAfterBlock: Int? = nil,
    feePerBlock: BillingMoneyAmount
  ) {
    self.id = id
    self.startsAtBlock = startsAtBlock
    self.endsAfterBlock = endsAfterBlock
    self.feePerBlock = feePerBlock
  }
}

public struct BillingPlanUnitPrice: Codable, Equatable, Sendable {
  public var name: String
  public var blockSize: Int
  public var tiers: [BillingPlanUnitPriceTier]

  public init(
    name: String,
    blockSize: Int,
    tiers: [BillingPlanUnitPriceTier]
  ) {
    self.name = name
    self.blockSize = blockSize
    self.tiers = tiers
  }
}

public struct BillingPlanPrice: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var fee: BillingMoneyAmount?
  public var annualMonthlyFee: BillingMoneyAmount?
  public var isDefault: Bool
  public var unitPrices: [BillingPlanUnitPrice]?

  public init(
    id: String,
    fee: BillingMoneyAmount? = nil,
    annualMonthlyFee: BillingMoneyAmount? = nil,
    isDefault: Bool,
    unitPrices: [BillingPlanUnitPrice]? = nil
  ) {
    self.id = id
    self.fee = fee
    self.annualMonthlyFee = annualMonthlyFee
    self.isDefault = isDefault
    self.unitPrices = unitPrices
  }
}

public struct BillingPlan: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var name: String
  public var fee: BillingMoneyAmount?
  public var annualFee: BillingMoneyAmount?
  public var annualMonthlyFee: BillingMoneyAmount?
  public var description: String?
  public var isDefault: Bool
  public var isRecurring: Bool
  public var hasBaseFee: Bool
  public var forPayerType: BillingPayerResourceType
  public var publiclyVisible: Bool
  public var slug: String
  public var avatarUrl: String?
  public var features: [Feature]
  public var unitPrices: [BillingPlanUnitPrice]?
  public var availablePrices: [BillingPlanPrice]?
  public var freeTrialDays: Int?
  public var freeTrialEnabled: Bool

  public init(
    id: String,
    name: String,
    fee: BillingMoneyAmount? = nil,
    annualFee: BillingMoneyAmount? = nil,
    annualMonthlyFee: BillingMoneyAmount? = nil,
    description: String? = nil,
    isDefault: Bool,
    isRecurring: Bool,
    hasBaseFee: Bool,
    forPayerType: BillingPayerResourceType,
    publiclyVisible: Bool,
    slug: String,
    avatarUrl: String? = nil,
    features: [Feature] = [],
    unitPrices: [BillingPlanUnitPrice]? = nil,
    availablePrices: [BillingPlanPrice]? = nil,
    freeTrialDays: Int? = nil,
    freeTrialEnabled: Bool = false
  ) {
    self.id = id
    self.name = name
    self.fee = fee
    self.annualFee = annualFee
    self.annualMonthlyFee = annualMonthlyFee
    self.description = description
    self.isDefault = isDefault
    self.isRecurring = isRecurring
    self.hasBaseFee = hasBaseFee
    self.forPayerType = forPayerType
    self.publiclyVisible = publiclyVisible
    self.slug = slug
    self.avatarUrl = avatarUrl
    self.features = features
    self.unitPrices = unitPrices
    self.availablePrices = availablePrices
    self.freeTrialDays = freeTrialDays
    self.freeTrialEnabled = freeTrialEnabled
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    fee = try container.decodeIfPresent(BillingMoneyAmount.self, forKey: .fee)
    annualFee = try container.decodeIfPresent(BillingMoneyAmount.self, forKey: .annualFee)
    annualMonthlyFee = try container.decodeIfPresent(BillingMoneyAmount.self, forKey: .annualMonthlyFee)
    description = try container.decodeIfPresent(String.self, forKey: .description)
    isDefault = try container.decode(Bool.self, forKey: .isDefault)
    isRecurring = try container.decode(Bool.self, forKey: .isRecurring)
    hasBaseFee = try container.decode(Bool.self, forKey: .hasBaseFee)
    forPayerType = try container.decode(BillingPayerResourceType.self, forKey: .forPayerType)
    publiclyVisible = try container.decode(Bool.self, forKey: .publiclyVisible)
    slug = try container.decode(String.self, forKey: .slug)
    avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
    features = try container.decodeIfPresent([Feature].self, forKey: .features) ?? []
    unitPrices = try container.decodeIfPresent([BillingPlanUnitPrice].self, forKey: .unitPrices)
    availablePrices = try container.decodeIfPresent([BillingPlanPrice].self, forKey: .availablePrices)
    freeTrialDays = try container.decodeIfPresent(Int.self, forKey: .freeTrialDays)
    freeTrialEnabled = try container.decodeIfPresent(Bool.self, forKey: .freeTrialEnabled) ?? false
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case name
    case fee
    case annualFee
    case annualMonthlyFee
    case description
    case isDefault
    case isRecurring
    case hasBaseFee
    case forPayerType
    case publiclyVisible
    case slug
    case avatarUrl
    case features
    case unitPrices
    case availablePrices
    case freeTrialDays
    case freeTrialEnabled
  }
}
