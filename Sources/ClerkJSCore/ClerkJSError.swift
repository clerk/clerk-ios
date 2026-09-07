import ClerkSnapshots
import Foundation

public struct ClerkJSError: Error, Sendable, Equatable, Decodable {
  public enum Kind: String, Sendable, Decodable {
    case api
    case offline
    case runtime
    case resolution
    case javascript
  }

  public var kind: Kind
  public var errors: [ClerkAPIError]
  public var clerkTraceId: String?
  public var status: Int?
  public var code: String?
  public var message: String

  public init(
    kind: Kind,
    errors: [ClerkAPIError] = [],
    clerkTraceId: String? = nil,
    status: Int? = nil,
    code: String? = nil,
    message: String
  ) {
    self.kind = kind
    self.errors = errors
    self.clerkTraceId = clerkTraceId
    self.status = status
    self.code = code
    self.message = message
  }

  public static func parse(_ raw: String) -> ClerkJSError {
    let json = raw.hasPrefix("Error: ") ? String(raw.dropFirst(7)) : raw
    if let data = json.data(using: .utf8),
       let parsed = try? JSONDecoder().decode(ClerkJSError.self, from: data)
    {
      return parsed
    }
    return ClerkJSError(kind: .javascript, message: raw)
  }
}
