import Foundation

package final class MockSessionService: SessionServiceProtocol {
  package nonisolated(unsafe) var setActiveHandler: ((String, String?) async throws -> Void)?
  package nonisolated(unsafe) var fetchTokenHandler:
    ((String, String?, SessionTokenRequestParams?) async throws -> TokenResource?)?

  package init(
    setActive: ((String, String?) async throws -> Void)? = nil,
    fetchToken: ((String, String?, SessionTokenRequestParams?) async throws -> TokenResource?)? = nil
  ) {
    setActiveHandler = setActive
    fetchTokenHandler = fetchToken
  }

  @MainActor
  package func setActive(sessionId: String, organizationId: String?) async throws {
    if let handler = setActiveHandler {
      try await handler(sessionId, organizationId)
    }
  }

  @MainActor
  package func fetchToken(
    sessionId: String,
    template: String?,
    params: SessionTokenRequestParams?
  ) async throws -> TokenResource? {
    if let handler = fetchTokenHandler {
      return try await handler(sessionId, template, params)
    }
    return nil
  }
}
