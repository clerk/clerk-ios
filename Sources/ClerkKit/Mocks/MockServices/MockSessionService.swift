import Foundation

package final class MockSessionService: SessionServiceProtocol {
  package nonisolated(unsafe) var setActiveHandler: ((String, String?) async throws -> Void)?

  package init(
    setActive: ((String, String?) async throws -> Void)? = nil
  ) {
    setActiveHandler = setActive
  }

  @MainActor
  package func setActive(sessionId: String, organizationId: String?) async throws {
    if let handler = setActiveHandler {
      try await handler(sessionId, organizationId)
    }
  }
}
