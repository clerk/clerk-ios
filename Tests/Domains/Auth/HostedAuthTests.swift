#if !os(watchOS) && !os(tvOS)
import ClerkJSCore
@testable import ClerkKit
import CryptoKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct HostedAuthFlowTests {
  @Test(arguments: ["myapp://callback", "myapp:///callback", "myapp://example.test:4242/callback"])
  func activatesCallbackSessionAfterRedeemingPKCE(redirect: String) async throws {
    let host = try await hostedAuthHarness()
    let oldSession = Clerk.shared.session?.id
    let result = try await Clerk.shared.auth.performHostedAuth(
      mode: .signUp, redirectUrl: redirect, prefersEphemeralWebBrowserSession: true,
      webAuthentication: { url, scheme, ephemeral in
        #expect(url.absoluteString == "https://accounts.example.com/sign-in")
        #expect(scheme == "myapp")
        #expect(ephemeral)
        #expect(Clerk.shared.session?.id == oldSession)
        return try await hostedCallback(host, redirect: redirect)
      }
    )
    #expect(result.id == "sess_hosted")
    #expect(Clerk.shared.session?.id == result.id)
    #expect(Clerk.shared.identityController.currentDeviceToken == "redeemed-token")
    let requests = try await hostedRequests(host)
    let create = try #require(requests.first { $0.path.hasSuffix("hosted_auth") })
    let redeem = try #require(requests.first { $0.body["rotating_token_nonce"] != nil })
    #expect(create.body["mode"] == "sign-up")
    #expect(create.body["redirect_url"] == redirect)
    #expect(create.body["state"]?.isEmpty == false)
    #expect(redeem.method == "POST")
    #expect(redeem.body["_method"] == "GET")
    #expect(redeem.body["rotating_token_nonce"] == "nonce_test")
    #expect(redeem.query["rotating_token_nonce"] == nil)
    #expect(redeem.query["code_verifier"] == nil)
    let verifier = try #require(redeem.body["code_verifier"])
    let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64EncodedString()
      .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    #expect(create.body["code_challenge"] == challenge)
    await Clerk.disposeEngine()
  }

  @Test(arguments: ["http://example.com", "https://example.com", "", "callback", " myapp://callback", "myapp://callback\n"])
  func rejectsInvalidRedirectBeforeRequest(redirect: String) async throws {
    let host = try await hostedAuthHarness()
    await #expect(throws: ClerkClientError.self) {
      try await Clerk.shared.auth.startHostedAuth(redirectUrl: redirect)
    }
    #expect(try await hostedRequests(host).isEmpty)
    await Clerk.disposeEngine()
  }

  @Test(arguments: ["wrong_scheme", "wrong_host", "wrong_path", "wrong_port", "credentials", "missing_authority", "missing_state", "duplicate_state", "wrong_state", "missing_nonce", "duplicate_nonce", "missing_session", "duplicate_session"])
  func rejectsInvalidCallbackWithoutRedeeming(scenario: String) async throws {
    let host = try await hostedAuthHarness()
    let oldClient = Clerk.shared.client
    await #expect(throws: ClerkClientError.self) {
      try await Clerk.shared.auth.performHostedAuth(
        mode: nil, redirectUrl: "myapp:///callback", prefersEphemeralWebBrowserSession: false,
        webAuthentication: { _, _, _ in
          let callback = try await hostedCallback(host, redirect: "myapp:///callback")
          var components = try #require(URLComponents(url: callback, resolvingAgainstBaseURL: false))
          switch scenario {
          case "wrong_scheme": components.scheme = "other"
          case "wrong_host": components.host = "attacker"
          case "wrong_path": components.path = "/other"
          case "wrong_port": components.port = 42
          case "credentials": components.user = "attacker"
          case "missing_authority": return try #require(URL(string: callback.absoluteString.replacingOccurrences(of: "myapp:///", with: "myapp:/")))
          case "wrong_state": components.queryItems?.removeAll { $0.name == "state" }; components.queryItems?.append(.init(name: "state", value: "wrong"))
          default:
            let field = scenario.hasSuffix("state") ? "state" : (scenario.hasSuffix("nonce") ? "rotating_token_nonce" : "created_session_id")
            if scenario.hasPrefix("missing") { components.queryItems?.removeAll { $0.name == field } }
            else { components.queryItems?.append(.init(name: field, value: "duplicate")) }
          }
          return try #require(components.url)
        }
      )
    }
    #expect(try await hostedRequests(host).filter { $0.body["rotating_token_nonce"] != nil }.isEmpty)
    #expect(Clerk.shared.client == oldClient)
    await Clerk.disposeEngine()
  }

  @Test(arguments: ["invalid_resource", "invalid_url", "missing_session", "clear", "redeem_error"])
  func rejectsInvalidHandoffWithoutActivating(scenario: String) async throws {
    let host = try await hostedAuthHarness(scenario: scenario)
    let oldClient = Clerk.shared.client
    let oldToken = Clerk.shared.identityController.currentDeviceToken
    await #expect(throws: (any Error).self) {
      try await Clerk.shared.auth.performHostedAuth(
        mode: nil, redirectUrl: "myapp://callback", prefersEphemeralWebBrowserSession: false,
        webAuthentication: { _, _, _ in try await hostedCallback(host) }
      )
    }
    let requests = try await hostedRequests(host)
    #expect(requests.filter { $0.path.hasSuffix("/touch") }.isEmpty)
    if scenario == "clear" {
      #expect(Clerk.shared.client == nil)
      #expect(Clerk.shared.identityController.currentDeviceToken == nil)
    } else {
      #expect(Clerk.shared.client == oldClient)
      #expect(Clerk.shared.identityController.currentDeviceToken == oldToken)
    }
    await Clerk.disposeEngine()
  }

  @Test
  func cancellationReleasesPendingFlowAndOverlappingStartIsRejected() async throws {
    let host = try await hostedAuthHarness()
    await #expect(throws: CancellationError.self) {
      try await Clerk.shared.auth.performHostedAuth(
        mode: nil, redirectUrl: "myapp://callback", prefersEphemeralWebBrowserSession: false,
        webAuthentication: { _, _, _ in
          do {
            try await Clerk.shared.auth.startHostedAuth(redirectUrl: "myapp://callback")
            Issue.record("An overlapping browser flow must fail")
          } catch is ClerkClientError {}
          throw CancellationError()
        }
      )
    }
    let result = try await Clerk.shared.auth.performHostedAuth(
      mode: nil, redirectUrl: "myapp://callback", prefersEphemeralWebBrowserSession: false,
      webAuthentication: { _, _, _ in try await hostedCallback(host) }
    )
    #expect(result.id == "sess_hosted")
    #expect(try await hostedRequests(host).filter { $0.path.hasSuffix("hosted_auth") }.count == 2)
    await Clerk.disposeEngine()
  }

  @Test(arguments: ["reconfigure", "identity_change"])
  func invalidatesBrowserFlowBeforeRedeem(scenario: String) async throws {
    let host = try await hostedAuthHarness()
    await #expect(throws: (any Error).self) {
      try await Clerk.shared.auth.performHostedAuth(
        mode: nil, redirectUrl: "myapp://callback", prefersEphemeralWebBrowserSession: false,
        webAuthentication: { _, _, _ in
          let callback = try await hostedCallback(host)
          if scenario == "reconfigure" {
            try await Clerk.reconfigure(publishableKey: "pk_test_" + Data("other.clerk.accounts.dev$".utf8).base64EncodedString())
          } else {
            Clerk.shared.identityController.fenceClientResponses()
          }
          return callback
        }
      )
    }
    // A replaced realm may already be disposed; the callback never reaches redemption.
    if let requests = try? await hostedRequests(host) {
      #expect(requests.filter { $0.body["rotating_token_nonce"] != nil }.isEmpty)
    }
    await Clerk.disposeEngine()
  }

  @Test(arguments: ["retry_create", "always_signed_out", "other_create_error"])
  func retriesOnlyAbandonedCreateWithSameProof(scenario: String) async throws {
    let host = try await hostedAuthHarness(scenario: scenario)
    do {
      let result = try await Clerk.shared.auth.performHostedAuth(
        mode: nil, redirectUrl: "myapp://callback", prefersEphemeralWebBrowserSession: false,
        webAuthentication: { _, _, _ in try await hostedCallback(host) }
      )
      #expect(scenario == "retry_create")
      #expect(result.id == "sess_hosted")
    } catch {
      #expect(scenario != "retry_create")
    }
    let creates = try await hostedRequests(host).filter { $0.path.hasSuffix("hosted_auth") }
    #expect(creates.count == (scenario == "other_create_error" ? 1 : 2))
    if creates.count == 2 { #expect(creates[0].body == creates[1].body) }
    await Clerk.disposeEngine()
  }

  @Test
  func identityChangeDuringRedeemDiscardsIncomingIdentity() async throws {
    let host = try await hostedAuthHarness(scenario: "hold_redeem")
    let original = Clerk.shared.client
    let task = Task {
      try await Clerk.shared.auth.performHostedAuth(
        mode: nil, redirectUrl: "myapp://callback", prefersEphemeralWebBrowserSession: false,
        webAuthentication: { _, _, _ in try await hostedCallback(host) }
      )
    }
    for _ in 0 ..< 200 {
      if try await host.runtime.evaluateJSON("typeof releaseHostedRedeem === 'function'") == "true" { break }
      try await Task.sleep(for: .milliseconds(5))
    }
    #expect(try await host.runtime.evaluateJSON("typeof releaseHostedRedeem === 'function'") == "true")
    Clerk.shared.identityController.fenceClientResponses()
    _ = try await host.runtime.evaluateJSON("(function() { releaseHostedRedeem(); return true; })()")
    await #expect(throws: (any Error).self) { try await task.value }
    #expect(Clerk.shared.client == original)
    #expect(Clerk.shared.identityController.currentDeviceToken == "fixture-client-jwt")
    await Clerk.disposeEngine()
  }
}

struct HostedRequest: Decodable {
  var path: String
  var method: String
  var body: [String: String]
  var query: [String: String]
}

@MainActor
func hostedRequests(_ host: ClerkJSHost) async throws -> [HostedRequest] {
  let json = try await host.runtime.evaluateJSON("hostedRequests")
  return try JSONDecoder().decode([HostedRequest].self, from: Data(json.utf8))
}

@MainActor
func hostedCallback(_ host: ClerkJSHost, redirect: String = "myapp://callback") async throws -> URL {
  let requests = try await hostedRequests(host)
  let state = try #require(requests.last { $0.path.hasSuffix("hosted_auth") }?.body["state"])
  var components = try #require(URLComponents(string: redirect))
  components.queryItems = [
    .init(name: "state", value: state), .init(name: "rotating_token_nonce", value: "nonce_test"),
    .init(name: "created_session_id", value: "sess_hosted"),
  ]
  return try #require(components.url)
}

@MainActor
func hostedAuthHarness(scenario: String = "success", configure: ((Clerk) throws -> Void)? = nil) async throws -> ClerkJSHost {
  let host = try await configureEmbeddedClerkForTesting(configure: configure)
  let fixture = try String(decoding: ClerkJSHost.snapshotSignedInClient(), as: UTF8.self)
  let scenarioJSON = try String(decoding: JSONEncoder().encode(scenario), as: UTF8.self)
  _ = try await host.runtime.evaluateJSON("""
    (function() {
      globalThis.hostedRequests = [];
      var scenario = \(scenarioJSON);
      var createCount = 0;
      var client = \(fixture);
      var session = client.sessions[0];
      session.id = 'sess_hosted';
      session.expire_at = Date.now() + 3600000;
      session.abandon_at = Date.now() + 86400000;
      session.last_active_token.jwt = btoa(JSON.stringify({alg:'RS256'})).replace(/=+$/, '') + '.' + btoa(JSON.stringify({sub:'user_fixture',sid:'sess_hosted',iat:Math.floor(Date.now()/1000),exp:Math.floor(Date.now()/1000)+3600})).replace(/=+$/, '') + '.sig';
      client.sign_in = null;
      client.sign_up = null;
      client.sessions = [__clerkInstance.client.sessions[0].__internal_toSnapshot(), session];
      client.last_active_session_id = 'sess_fixture';
      globalThis.fetch = async function(url, options) {
        var body = Object.fromEntries(new URLSearchParams(options.body || ''));
        hostedRequests.push({path:url.pathname,method:options.method,body:body,query:Object.fromEntries(url.searchParams)});
        var response;
        var status = 200;
        var headers = new Headers();
        if (url.pathname === '/v1/client/hosted_auth') {
          createCount++;
          if (scenario === 'always_signed_out' || (scenario === 'retry_create' && createCount === 1) || scenario === 'other_create_error') {
            return {status:422,ok:false,headers,json:async () => ({errors:[{code:scenario === 'other_create_error' ? 'invalid' : 'signed_out',message:'create failed'}]})};
          }
          response = {object:scenario === 'invalid_resource' ? 'client' : 'hosted_auth',url:scenario === 'invalid_url' ? 'http://accounts.example.com' : 'https://accounts.example.com/sign-in'};
        } else if (url.pathname === '/v1/client' && options.method === 'POST') {
          if (scenario === 'hold_redeem') await new Promise(resolve => { globalThis.releaseHostedRedeem = resolve; });
          response = scenario === 'missing_session' ? {...client,sessions:[]} : client;
          headers.set('authorization', scenario === 'clear' ? '' : 'redeemed-token');
          if (scenario === 'redeem_error') {
            return {status:422,ok:false,headers:new Headers(),json:async () => ({errors:[{code:'signed_out',message:'signed out'}]})};
          }
        } else if (url.pathname.endsWith('/touch')) {
          response = session;
        } else if (url.pathname === '/v1/client') {
          response = __clerkInstance.client.__internal_toSnapshot();
        } else {
          throw new Error('Unexpected hosted request: ' + url.pathname);
        }
        return {status,ok:true,headers,json:async () => ({response})};
      };
      return true;
    })()
    """)
  return host
}
#endif
