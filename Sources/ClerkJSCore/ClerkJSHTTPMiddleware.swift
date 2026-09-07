import Foundation

/// Host transport hooks applied around each JavaScript fetch.
public struct ClerkJSHTTPMiddleware: Sendable {
  public var prepare: @Sendable (URLRequest) async throws -> URLRequest
  public var validate: @Sendable (HTTPURLResponse, Data, URLRequest) async throws -> Void

  public init(
    prepare: @escaping @Sendable (URLRequest) async throws -> URLRequest = { $0 },
    validate: @escaping @Sendable (HTTPURLResponse, Data, URLRequest) async throws -> Void = { _, _, _ in }
  ) {
    self.prepare = prepare
    self.validate = validate
  }
}
