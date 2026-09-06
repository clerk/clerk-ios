@_exported import ClerkSnapshots
import Foundation

public enum WatchCompanionError: Error, Equatable, Sendable {
  case invalidClientPayload
  case invalidEnvironmentPayload
}

public struct WatchCompanion: Equatable, Sendable {
  public static let clientKey = "clerkClient"
  public static let environmentKey = "clerkEnvironment"

  public var client: Client?
  public var environment: Environment?

  public init(client: Client? = nil, environment: Environment? = nil) {
    self.client = client
    self.environment = environment
  }

  public init(applicationContext: [String: Any]) throws {
    self.init()
    try apply(applicationContext)
  }

  public mutating func apply(_ applicationContext: [String: Any]) throws {
    if let value = applicationContext[Self.clientKey] {
      guard let data = value as? Data else {
        throw WatchCompanionError.invalidClientPayload
      }
      client = try FAPIJSON.decodeClient(data)
    }

    if let value = applicationContext[Self.environmentKey] {
      guard let data = value as? Data else {
        throw WatchCompanionError.invalidEnvironmentPayload
      }
      environment = try JSONDecoder().decode(Environment.self, from: data)
    }
  }
}
