//
//  Environment.swift
//

import Foundation

extension Clerk {
  public struct Environment: Codable, Sendable, Equatable {
    public var authConfig: AuthConfig
    public var userSettings: UserSettings
    public var displayConfig: DisplayConfig
    public var fraudSettings: FraudSettings

    public init(
      authConfig: AuthConfig,
      userSettings: UserSettings,
      displayConfig: DisplayConfig,
      fraudSettings: FraudSettings
    ) {
      self.authConfig = authConfig
      self.userSettings = userSettings
      self.displayConfig = displayConfig
      self.fraudSettings = fraudSettings
    }

    private enum CodingKeys: String, CodingKey {
      case authConfig
      case userSettings
      case displayConfig
      case fraudSettings
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      authConfig = try container.decode(AuthConfig.self, forKey: .authConfig)
      userSettings = try container.decode(UserSettings.self, forKey: .userSettings)
      displayConfig = try container.decode(DisplayConfig.self, forKey: .displayConfig)
      // Keep decoding resilient if older/newer backends omit the deprecated fraud settings payload.
      fraudSettings = try container.decodeIfPresent(FraudSettings.self, forKey: .fraudSettings) ?? .init()
    }
  }
}

extension Clerk.Environment {
  /// Creates an environment from a JSON file.
  ///
  /// This initializer allows you to create a mock environment from a JSON file containing a real API response,
  /// which is useful for SwiftUI previews that need to match your production environment configuration.
  ///
  /// - Parameter fileURL: A file URL pointing to a JSON file containing the environment response.
  /// - Throws: `DecodingError` if the file cannot be read or decoded into an `Environment`.
  ///
  /// Example:
  /// ```swift
  /// #Preview {
  ///   MyView()
  ///     .environment(Clerk.preview { builder in
  ///       let url = Bundle.main.url(forResource: "environment", withExtension: "json")!
  ///       builder.environment = try! Clerk.Environment(fromFile: url)
  ///     })
  /// }
  /// ```
  init(fromFile fileURL: URL) throws {
    let data = try Data(contentsOf: fileURL)
    self = try JSONDecoder.clerkDecoder.decode(Clerk.Environment.self, from: data)
  }
}
