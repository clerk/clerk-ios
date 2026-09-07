#if !os(watchOS)
@testable import ClerkJSCore
import Foundation
import Testing

@MainActor
struct ClerkEmbeddedLifecycleTests {
  private let key = "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk"

  private func fixture(_ name: String) throws -> String {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
    return try String(contentsOf: url, encoding: .utf8)
  }

  private func host(signedIn: Bool = false) async throws -> ClerkJSHost {
    let host = ClerkJSHost(publishableKey: key, tokenCache: .init(getToken: { "restored-client-jwt" }, saveToken: { _ in }))
    let environment = try fixture("environment-snapshot")
    let client = try fixture(signedIn ? "signed-in-client" : "unsigned-client")
    _ = try await host.runtime.evaluateJSON("""
      (function() {
        globalThis.requests = [];
        globalThis.fixtureEnvironment = \(environment);
        globalThis.fixtureClient = \(client);
        globalThis.mintCount = 0;
        globalThis.makeToken = function(expiration) {
          return btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' })).replace(/=+$/g, '') + '.' +
            btoa(JSON.stringify({ sub: 'user_fixture', sid: 'sess_fixture', iat: Math.floor(Date.now() / 1000), exp: expiration })).replace(/=+$/g, '') + '.signature';
        };
        if (fixtureClient.sessions.length) {
          fixtureClient.sessions[0].expire_at = Date.now() + 3600000;
          fixtureClient.sessions[0].abandon_at = Date.now() + 86400000;
          fixtureClient.sessions[0].last_active_token.jwt = makeToken(Math.floor(Date.now() / 1000) - 60);
        }
        globalThis.fixtureInvitation = { object: 'organization_invitation', id: 'inv_fixture', organization_id: 'org_fixture', email_address: 'test@example.com', public_metadata: {}, role: 'org:member', role_name: 'Member', status: 'pending', created_at: 1700000000000, updated_at: 1700000000000 };
        globalThis.fetch = async function(url, options) {
          var path = url.pathname;
          requests.push({ path: path, method: options.method, token: options.headers.get('authorization'), native: url.searchParams.get('_is_native') });
          var response;
          if (path === '/v1/environment') response = fixtureEnvironment;
          else if (path === '/v1/client') response = fixtureClient;
          else if (path === '/v1/client/sessions/sess_fixture/touch') response = fixtureClient.sessions[0];
          else if (path === '/v1/client/sessions/sess_fixture/tokens') { mintCount += 1; response = { object: 'token', jwt: makeToken(Math.floor(Date.now() / 1000) + 30 + mintCount) }; }
          else if (path === '/v1/client/sessions/sess_fixture/remove') { fixtureClient.sessions = []; fixtureClient.last_active_session_id = null; response = fixtureClient; }
          else if (path === '/v1/organizations/org_fixture') response = { object: 'organization', id: 'org_fixture', name: 'Fixture', slug: 'fixture', public_metadata: {}, members_count: 0, created_at: 1700000000000, updated_at: 1700000000000 };
          else if (path.endsWith('/invitations/inv_fixture/revoke')) { fixtureInvitation.status = 'revoked'; response = fixtureInvitation; }
          else if (path.endsWith('/invitations')) response = { data: [fixtureInvitation], total_count: 1 };
          else throw new Error('Unexpected request: ' + path);
          return { status: 200, ok: true, headers: new Headers({ authorization: 'fixture-client-jwt' }), json: async function() { return path.endsWith('/tokens') ? response : { response: response }; } };
        };
        return true;
      })()
      """)
    return host
  }

  @Test
  func refreshPublishesLatestStateAndUsesNativeCredential() async throws {
    let host = try await host()
    try await host.load()
    #expect(host.state?.client?.id == "client_fixture")
    let revision = try #require(host.state?.revision)
    _ = try await host.runtime.evaluateJSON("fixtureClient.id = 'client_refreshed'")
    _ = try await host.invoke(.init(receiver: .clerk, method: "refreshClient", arguments: []))
    #expect(host.state?.client?.id == "client_refreshed")
    #expect(try #require(host.state?.revision) > revision)
    #expect(host.state?.clientToken == "fixture-client-jwt")
    let requests = try await host.runtime.evaluateJSON("requests.filter(r => r.path === '/v1/client')")
    let rows = try #require(JSONSerialization.jsonObject(with: Data(requests.utf8)) as? [[String: Any]])
    #expect(rows.count == 2)
    #expect(rows.last?["token"] as? String == "fixture-client-jwt")
    #expect(rows.allSatisfy { $0["native"] as? String == "1" })
    await host.dispose()
  }

  @Test
  func expiredTokenUsesSharedCacheAndHonorsExpirationBuffer() async throws {
    let host = try await host(signedIn: true)
    try await host.load()
    let call = ClerkJSInvocation(receiver: .session(id: .init("sess_fixture")), method: "getToken", arguments: [])
    async let first = host.invoke(call)
    async let second = host.invoke(call)
    let (firstToken, secondToken) = try await (first, second)
    #expect(firstToken == secondToken)
    let initialMints = try await host.runtime.evaluateJSON("mintCount")
    #expect(initialMints == "1")
    _ = try await host.invoke(.init(receiver: call.receiver, method: "getToken", arguments: [.object(["expirationBuffer": .number(59)])]))
    #expect(try await host.runtime.evaluateJSON("mintCount") == "2")
    #expect(host.state?.client?.sessions.first?.lastActiveToken.jwt.isEmpty == false)
    await host.dispose()
  }

  @Test
  func listedInvitationCanBeRevokedInMinifiedBundle() async throws {
    let host = try await host()
    try await host.load()
    let listed = try await host.invoke(.init(receiver: .organization(id: .init("org_fixture")), method: "getInvitations", arguments: []))
    #expect(try String(data: listed.data(), encoding: .utf8)?.contains("inv_fixture") == true)
    let revoked = try await host.invoke(.init(receiver: .listed(.organizationInvitation, id: .init("inv_fixture")), method: "revoke", arguments: []))
    #expect(try String(data: revoked.data(), encoding: .utf8)?.contains("revoked") == true)
    await host.dispose()
  }

  @Test
  func apiFailurePublishesClientAndKeepsStructuredError() async throws {
    let host = try await host()
    try await host.load()
    _ = try await host.runtime.evaluateJSON("""
      (function() {
        globalThis.fetch = async function() {
          fixtureClient.id = 'client_after_error';
          return {
            status: 422, ok: false, headers: new Headers({ authorization: 'jwt_after_error' }),
            json: async function() { return { client: fixtureClient, errors: [{ code: 'form_identifier_not_found', message: 'Identifier not found', long_message: 'No account matches this identifier' }] }; }
          };
        };
        return true;
      })()
      """)
    do {
      _ = try await host.invoke(.init(receiver: .signIn, method: "create", arguments: [.object(["identifier": .string("missing@example.com")])]))
      Issue.record("Expected sign-in to fail")
    } catch let error as ClerkJSError {
      #expect(error.kind == .api)
      #expect(error.errors.first?.code == "form_identifier_not_found")
      #expect(error.status == 422)
    }
    #expect(host.state?.client?.id == "client_after_error")
    #expect(host.state?.clientToken == "jwt_after_error")
    await host.dispose()
  }

  @Test
  func disposingRejectsFurtherCallsAndFreshRealmLoads() async throws {
    let first = try await host()
    try await first.load()
    await first.dispose()
    await #expect(throws: (any Error).self) {
      try await first.invoke(.init(receiver: .clerk, method: "refreshClient", arguments: []))
    }
    let second = try await host()
    try await second.load()
    #expect(second.state?.generation != first.state?.generation)
    #expect(second.state?.client?.id == "client_fixture")
    await second.dispose()
  }

  @Test
  func cancelingOneWaiterDoesNotCancelAnotherPromise() async throws {
    let runtime = ClerkJSRuntime()
    let first = Task { try await runtime.evaluateJSON("new Promise(resolve => { globalThis.resolveFirst = resolve; })") }
    let second = Task { try await runtime.evaluateJSON("new Promise(resolve => { globalThis.resolveSecond = resolve; })") }
    while try await runtime.evaluateJSON("typeof resolveFirst === 'function' && typeof resolveSecond === 'function'") != "true" {
      await Task.yield()
    }
    first.cancel()
    await #expect(throws: ClerkJSCoreError.cancelled) { try await first.value }
    _ = try await runtime.evaluateJSON("resolveSecond('second')")
    #expect(try await second.value == "\"second\"")
    _ = try await runtime.evaluateJSON("resolveFirst('late')")
    await runtime.dispose()
  }
}
#endif
