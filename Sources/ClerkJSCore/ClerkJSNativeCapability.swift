import ClerkSnapshots
import Foundation

public typealias ClerkJSNativeCapability = @Sendable (JSONValue) async throws -> JSONValue

public struct ClerkJSNativeCapabilityError: Error, Sendable, Codable {
  public let code: String
  public let message: String
  public let nativeError: JSONValue

  public init(code: String, message: String, nativeError: JSONValue) {
    self.code = code
    self.message = message
    self.nativeError = nativeError
  }
}
