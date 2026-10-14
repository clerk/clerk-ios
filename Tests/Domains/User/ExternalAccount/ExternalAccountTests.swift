@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ExternalAccountTests {
  private let transport = FakeTransport.mockDefaults()

  init() {
    configureClerkForTesting()
  }

  private func configureTransport() {
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      transport: transport
    )
  }

  @Test
  func prepareReauthorizationDefaultsRedirectUrlToConfiguredRedirect() async throws {
    let externalAccount = ExternalAccount.mockVerified
    let expectedRedirectUrl = Clerk.shared.options.redirectConfig.redirectUrl
    let captured = LockIsolated<(String, JSON?)?>(nil)
    transport.stub(ExternalAccountAPI.reauthorize(externalAccountId: FakeTransport.anyPathSegment, redirectUrl: "", additionalScopes: [], oidcPrompts: [])) { call in
      captured.setValue((String(call.path.split(separator: "/")[3]), call.body))
      return ClientResponse(response: .mockVerified, client: nil)
    }

    configureTransport()

    _ = try await externalAccount.prepareReauthorization(additionalScopes: ["write", "view"])

    let params = try #require(captured.value)
    #expect(params.0 == externalAccount.id)
    #expect(params.1?["redirect_url"]?.stringValue == expectedRedirectUrl)
    #expect(params.1?["additional_scope"] == .array([.string("write"), .string("view")]))
    #expect(params.1?["oidc_prompt"] == nil)
  }

  @Test
  func destroySendsExternalAccountId() async throws {
    let externalAccount = ExternalAccount.mockVerified
    let captured = LockIsolated<String?>(nil)
    transport.stub(ExternalAccountAPI.destroy(externalAccountId: FakeTransport.anyPathSegment)) { call in
      captured.setValue(String(call.path.split(separator: "/")[3]))
      return ClientResponse(response: .mock, client: nil)
    }

    configureTransport()

    _ = try await externalAccount.destroy()

    #expect(captured.value == externalAccount.id)
  }
}
