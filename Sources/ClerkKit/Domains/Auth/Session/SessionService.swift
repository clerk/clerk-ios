import ClerkSnapshots
import Foundation

protocol SessionServiceProtocol: Sendable {
  @MainActor func setActive(sessionId: String, organizationId: String?) async throws
}

final class SessionService: SessionServiceProtocol {
  init() {}

  @MainActor
  func setActive(sessionId: String, organizationId: String?) async throws {
    try await Clerk.js(.clerk, ClerkJSCall.setActive(.init(session: .string(sessionId), organization: organizationId.map(JSONValue.string) ?? .null)))
  }
}
