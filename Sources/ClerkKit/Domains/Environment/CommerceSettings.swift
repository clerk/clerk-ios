import ClerkSnapshots
import Foundation

extension Clerk.Environment {
  public typealias CommerceSettings = ClerkSnapshots.CommerceSettings
}

extension Clerk.Environment.CommerceSettings {
  public typealias Billing = CommerceSettingsBilling
  public static let `default` = CommerceSettings.empty
}

extension Clerk.Environment.CommerceSettings.Billing {
  public typealias Payer = CommerceSettingsBillingOrganization
}
