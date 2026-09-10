import ClerkKit
import Testing

@MainActor
@Suite(.serialized, .enabled(if: integrationTestsEnabled(keyName: "with-email-codes"), "Requires with-email-codes in .keys.json"))
struct EnvironmentIntegrationTests {
  @Test
  func fetchAndDecodeEnvironment() async throws {
    let clerk = try await connectClerkForIntegrationTesting(keyName: "with-email-codes")
    defer { clerk.close() }
    #expect(clerk.loaded)
    #expect(clerk.session == nil)
    let environment = try await clerk.environment.reload()
    #expect(!environment.isInvalidated)
    #expect(try await environment.isDevelopmentOrStaging())
  }
}
