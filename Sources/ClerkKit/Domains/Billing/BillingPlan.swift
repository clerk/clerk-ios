import ClerkSnapshots
import Foundation

public typealias BillingPlan = ClerkSnapshots.BillingPlan
public typealias BillingPlanUnitPrice = ClerkSnapshots.BillingPlanUnitPrice
public typealias BillingPlanUnitPriceTier = ClerkSnapshots.BillingPlanUnitPriceTier
public typealias BillingPrice = ClerkSnapshots.BillingPrice
public typealias BillingPlanPrice = ClerkSnapshots.BillingPrice
public typealias BillingPlanForPayerType = ClerkSnapshots.BillingPlanForPayerType
public typealias BillingPayerResourceType = ClerkSnapshots.BillingPlanForPayerType

extension BillingPlan {
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
    forPayerType: BillingPlanForPayerType,
    publiclyVisible: Bool,
    slug: String,
    avatarUrl: String? = nil,
    features: [Feature] = [],
    unitPrices: [BillingPlanUnitPrice]? = nil,
    availablePrices: [BillingPrice]? = nil,
    freeTrialDays: Int? = nil,
    freeTrialEnabled: Bool = false
  ) {
    self.init(
      object: "commerce_plan",
      id: id,
      name: name,
      fee: fee,
      annualFee: annualFee,
      annualMonthlyFee: annualMonthlyFee,
      description: description,
      isDefault: isDefault,
      isRecurring: isRecurring,
      hasBaseFee: hasBaseFee,
      forPayerType: forPayerType,
      publiclyVisible: publiclyVisible,
      slug: slug,
      avatarUrl: avatarUrl,
      features: features,
      freeTrialDays: freeTrialDays,
      freeTrialEnabled: freeTrialEnabled,
      unitPrices: unitPrices,
      availablePrices: availablePrices
    )
  }
}

extension BillingPrice {
  public init(
    id: String,
    fee: BillingMoneyAmount? = nil,
    annualMonthlyFee: BillingMoneyAmount? = nil,
    isDefault: Bool,
    unitPrices: [BillingPlanUnitPrice]? = nil
  ) {
    self.init(
      object: "commerce_price",
      fee: fee,
      annualMonthlyFee: annualMonthlyFee,
      isDefault: isDefault,
      unitPrices: unitPrices,
      id: id
    )
  }
}

extension BillingPlanUnitPriceTier {
  public init(
    id: String? = nil,
    startsAtBlock: Int,
    endsAfterBlock: Int? = nil,
    feePerBlock: BillingMoneyAmount
  ) {
    self.init(
      id: id ?? "",
      object: "commerce_plan_unit_price_tier",
      startsAtBlock: startsAtBlock,
      endsAfterBlock: endsAfterBlock,
      feePerBlock: feePerBlock
    )
  }
}
