import ClerkSnapshots
import Foundation

public typealias BillingCreditBalance = ClerkSnapshots.BillingCreditBalance

extension BillingCreditBalance {
  public init(balance: BillingMoneyAmount? = nil) {
    self.init(object: "commerce_credit_balance", balance: balance)
  }
}
