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
  public var environment: ClerkEnvironment?

  public init(client: Client? = nil, environment: ClerkEnvironment? = nil) {
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
      environment = try JSONDecoder().decode(ClerkEnvironment.self, from: data)
    }
  }

  public func encode() throws -> [String: Any] {
    var payload: [String: Any] = [:]
    if let client {
      payload[Self.clientKey] = try FAPIJSON.encodeClient(client)
    }
    if let environment {
      payload[Self.environmentKey] = try JSONEncoder().encode(environment)
    }
    return payload
  }
}
