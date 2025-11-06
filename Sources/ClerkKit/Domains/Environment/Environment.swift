//
//  Environment.swift
//
//
//  Created by Mike Pitre on 10/5/23.
//

import Foundation

public extension Clerk {
  struct Environment: Codable, Sendable, Equatable {
    public var authConfig: AuthConfig?
    public var userSettings: UserSettings?
    public var displayConfig: DisplayConfig?
    public var fraudSettings: FraudSettings?
    public var commerceSettings: CommerceSettings?

    public var isEmpty: Bool {
      authConfig == nil && userSettings == nil && displayConfig == nil && fraudSettings == nil && commerceSettings == nil
    }
  }
}

extension Clerk.Environment {
  @MainActor
  private static var environmentService: any EnvironmentServiceProtocol { Clerk.shared.dependencies.environmentService }

  @MainActor
  public static func get() async throws -> Clerk.Environment {
    try await environmentService.get()
  }

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
  ///     .clerkPreview { builder in
  ///       let url = Bundle.main.url(forResource: "environment", withExtension: "json")!
  ///       builder.environment = try! Clerk.Environment(fromFile: url)
  ///     }
  /// }
  /// ```
  init(fromFile fileURL: URL) throws {
    let data = try Data(contentsOf: fileURL)
    self = try JSONDecoder.clerkDecoder.decode(Clerk.Environment.self, from: data)
  }
}
