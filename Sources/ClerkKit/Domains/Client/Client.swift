import ClerkSnapshots
import Foundation

extension Client {
  /// Sessions on this client whose status is active.
  public var activeSessions: [Session] {
    sessions.filter { $0.status == .active }
  }
}
