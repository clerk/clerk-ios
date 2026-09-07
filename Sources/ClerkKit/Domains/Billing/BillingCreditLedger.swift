import ClerkSnapshots
import Foundation

public typealias BillingCreditLedger = ClerkSnapshots.BillingCreditLedger

extension BillingCreditLedger {
  public init(
    id: String,
    amount: BillingMoneyAmount,
    sourceType: String,
    sourceId: String,
    createdAt: Date
  ) {
    self.init(
      object: "commerce_credit_ledger",
      id: id,
      amount: amount,
      sourceType: sourceType,
      sourceId: sourceId,
      createdAt: createdAt
    )
  }
}
