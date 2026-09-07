import ClerkSnapshots
import Foundation

public struct ClerkJSState: Decodable, Sendable {
  public let protocolVersion: Int
  public let generation: String
  public let revision: UInt64
  public let status: String
  public let client: ClerkSnapshots.Client?
  public let environment: ClerkEnvironment?
  public let clientToken: String
  public let tokenEvent: TokenEvent?

  public struct TokenEvent: Decodable, Sendable {
    public let sequence: UInt64
    public let sessionId: String
    public let jwt: String
  }
}
