import ClerkSnapshots
import Foundation

/// An object that represents an error returned by the Clerk API.
public typealias ClerkAPIError = ClerkSnapshots.ClerkAPIError

extension ClerkAPIError {
  public convenience init(
    code: String,
    message: String? = nil,
    longMessage: String? = nil,
    meta: ClerkAPIErrorMeta? = nil,
    clerkTraceId: String? = nil
  ) {
    self.init(
      code: code,
      message: message ?? "",
      longMessage: longMessage,
      meta: meta,
      clerkTraceId: clerkTraceId ?? ""
    )
  }

  public var context: [String: String]? {
    var ctx: [String: String] = [:]
    if !clerkTraceId.isEmpty {
      ctx["traceId"] = clerkTraceId
    }
    if let paramName = meta?.paramName {
      ctx["paramName"] = paramName
    }
    return ctx.isEmpty ? nil : ctx
  }
}

/// Represents the body of Clerk API error responses.
///
/// The `ClerkErrorResponse` structure encapsulates multiple API errors that may occur during a request.
/// It also includes a unique trace ID for debugging purposes.
public struct ClerkErrorResponse: Codable, Equatable {
  /// An array of `ClerkAPIError` objects, each describing an individual error.
  public var errors: [ClerkAPIError]

  /// A unique identifier for tracing the specific request, useful for debugging.
  public var clerkTraceId: String?
}
