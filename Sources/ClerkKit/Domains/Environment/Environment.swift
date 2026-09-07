import ClerkSnapshots
import Foundation

extension Clerk {
  public typealias Environment = ClerkSnapshots.ClerkEnvironment
}

extension Clerk.Environment {
  public init(
    authConfig: AuthConfig,
    userSettings: UserSettings,
    displayConfig: DisplayConfig,
    organizationSettings: OrganizationSettings = .empty,
    commerceSettings: CommerceSettings = .empty
  ) {
    self.init(
      apiKeysSettings: .empty,
      authConfig: authConfig,
      commerceSettings: commerceSettings,
      displayConfig: displayConfig,
      maintenanceMode: false,
      organizationSettings: organizationSettings,
      userSettings: userSettings,
      protectConfig: .empty,
      id: "",
      object: "environment"
    )
  }

  /// Creates an environment from a JSON file.
  ///
  /// - Parameter fileURL: A file URL pointing to a JSON file containing the environment response.
  /// - Throws: `DecodingError` if the file cannot be read or decoded into an `Environment`.
  init(fromFile fileURL: URL) throws {
    let data = try Data(contentsOf: fileURL)
    self = try JSONDecoder.clerkDecoder.decode(Clerk.Environment.self, from: data)
  }
}
