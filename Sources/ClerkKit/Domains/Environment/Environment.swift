//
//  Environment.swift
//

import Foundation

extension Clerk {
  public struct Environment: Codable, Sendable, Equatable {
    public var authConfig: AuthConfig
    public var userSettings: UserSettings
    public var displayConfig: DisplayConfig

    public init(
      authConfig: AuthConfig,
      userSettings: UserSettings,
      displayConfig: DisplayConfig
    ) {
      self.authConfig = authConfig
      self.userSettings = userSettings
      self.displayConfig = displayConfig
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
