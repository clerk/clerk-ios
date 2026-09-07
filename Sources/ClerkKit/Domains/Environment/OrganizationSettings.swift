import ClerkSnapshots
import Foundation

extension Clerk.Environment {
  public typealias OrganizationSettings = ClerkSnapshots.OrganizationSettings
}

extension Clerk.Environment.OrganizationSettings {
  public typealias Actions = OrganizationSettingsActions
  public typealias Domains = OrganizationSettingsDomains
  public typealias Slug = OrganizationSettingsSlug
  public typealias CreationDefaults = OrganizationSettingsOrganizationCreationDefaults
  public static let `default` = OrganizationSettings.empty
}
