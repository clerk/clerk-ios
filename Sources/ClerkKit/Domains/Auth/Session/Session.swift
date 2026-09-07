import ClerkSnapshots
import Foundation

extension Session {
  package var pendingTasks: [Task] {
    tasks ?? []
  }

  /// Options that can be passed as parameters to the `getToken()` function.
  public struct GetTokenOptions: Sendable {
    /// The name of the JWT template from the Clerk Dashboard to generate a new token from. E.g. 'firebase', 'grafbase', or your custom template's name.
    public var template: String?

    /// If the cached token will expire within X seconds (the buffer), fetch a new token instead. Max is 60 seconds.
    public var expirationBuffer: Double

    /// Whether to skip the cache lookup and force a call to the server instead, even within the TTL. Useful if the token claims are time-sensitive or depend on data that can be updated (e.g. user fields). Defaults to false.
    public var skipCache: Bool

    public init(
      template: String? = nil,
      expirationBuffer: Double = 10,
      skipCache: Bool = false
    ) {
      self.template = template
      self.expirationBuffer = min(expirationBuffer, 60)
      self.skipCache = skipCache
    }
  }
}
