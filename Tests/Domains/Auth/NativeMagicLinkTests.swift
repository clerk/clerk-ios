#if !os(watchOS)
import ClerkJSCore
@testable import ClerkKit
import ConcurrencyExtras
import CryptoKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct NativeMagicLinkTests {
  @Test(arguments: ["signIn", "signUp"])
  func persistsPKCEBeforePreparingAndCompletesThroughSharedAuth(flow: String) async throws {
    let keychain = MagicKeychain()
    let host = try await magicHarness(flow: flow, keychain: keychain)
    let registration = try #require(Clerk.shared.registerAuthFlow())
    try await AuthFlowRequestScope.withOwner(registration.id) { try await sendMagic(flow: flow) }
    let pending = try #require(try keychain.pending())
    #expect(pending.kind == flow)
    #expect(pending.flowId == (flow == "signIn" ? "sia_magic" : "sua_magic"))
    #expect(pending.expiresAt - pending.createdAt == 600_000)
    #expect(pending.codeVerifier.count == 43)
    let requests = try await magicRequests(host)
    let prepare = try #require(requests.last)
    #expect(prepare.body["code_challenge_method"] == "S256")
    #expect(prepare.body["code_challenge"] == magicChallenge(pending.codeVerifier))
    #expect(prepare.body["redirect_url"] == "myapp://callback")
    if flow == "signIn" { #expect(prepare.body["email_address_id"] == "ema_match") }
    #expect(try await host.runtime.evaluateJSON("JSON.parse(magicSavedAtPrepare).code_verifier.length") == "43")
    let result = try await Clerk.shared.auth.completeMagicLink(callbackURL: magicURL(flowId: #require(pending.flowId)))
    #expect(result.createdSessionId == "sess_magic")
    #expect(Clerk.shared.session?.id == "sess_magic")
    #expect(Clerk.shared.identityController.currentDeviceToken == "redeemed-magic-token")
    #expect(try keychain.pending() == nil)
    let completedRequests = try await magicRequests(host)
    let redeem = try #require(completedRequests.first { $0.path.hasSuffix("/magic_links/complete") })
    #expect(redeem.body["code_verifier"] == pending.codeVerifier)
    #expect(redeem.body["approval_token"] == "approval_magic")
    #expect(redeem.token == "magic-client-token")
    #expect(completedRequests.last?.path.hasSuffix("/touch") == true)
    let snapshot = try #require(Clerk.shared.authFlowSnapshot(for: registration))
    guard case .awaiting(let work, _) = snapshot.phase else { Issue.record("Expected native auth-view completion work"); return }
    #expect(!Clerk.shared.isAuthFlowComplete)
    #expect(Clerk.shared.completeAuthFlow(work))
    #expect(Clerk.shared.isAuthFlowComplete)
    withExtendedLifetime(registration) {}
    await Clerk.disposeEngine()
  }

  @Test
  func oneShotTrimsEmailAndExplicitRecipientOverridesSelection() async throws {
    let host = try await magicHarness(create: false)
    let signIn = try await Clerk.shared.auth.signInWithEmailLink(emailAddress: " ada@example.com \n")
    var requests = try await magicRequests(host)
    #expect(requests[0].body["identifier"] == "ada@example.com")
    #expect(requests[1].body["email_address_id"] == "ema_match")
    try await signIn.sendEmailLink(emailAddressId: "ema_override", redirectUri: "other://return")
    requests = try await magicRequests(host)
    #expect(requests[2].body["email_address_id"] == "ema_override")
    #expect(requests[2].body["redirect_url"] == "other://return")
    await Clerk.disposeEngine()
  }

  @Test(arguments: ["signIn", "signUp"])
  func storageFailureStopsPreparationAndPreparationFailurePreservesVerifier(flow: String) async throws {
    let keychain = MagicKeychain()
    let host = try await magicHarness(flow: flow, scenario: "prepare_failure", keychain: keychain)
    keychain.rejectPendingWrites.setValue(true)
    await #expect(throws: ClerkClientError.self) { try await sendMagic(flow: flow) }
    #expect(try await magicRequests(host).count == 1)
    keychain.rejectPendingWrites.setValue(false)
    await #expect(throws: ClerkAPIError.self) { try await sendMagic(flow: flow) }
    #expect(try keychain.pending()?.codeVerifier.isEmpty == false)
    await Clerk.disposeEngine()
  }

  @Test(arguments: ["signIn", "signUp"])
  func incompleteFlowEmitsNativeContinuation(flow: String) async throws {
    let host = try await magicHarness(flow: flow, scenario: "incomplete")
    try await sendMagic(flow: flow)
    let events = LockIsolated<[AuthEvent]>([])
    let listener = Task { @MainActor in
      for await event in Clerk.shared.auth.events {
        events.withValue { $0.append(event) }
      }
    }
    await Task.yield()
    let result = try await Clerk.shared.auth.completeMagicLink(flowId: flow == "signIn" ? "sia_magic" : "sua_magic", approvalToken: "approval_magic")
    await Task.yield()
    #expect(result.needsContinuation)
    #expect(Clerk.shared.callbackContinuation?.flowId == result.flowId)
    #expect(Clerk.shared.session == nil)
    #expect(events.value.contains { event in
      switch event {
      case .signInNeedsContinuation: flow == "signIn"
      case .signUpNeedsContinuation: flow == "signUp"
      default: false
      }
    })
    listener.cancel()
    await Clerk.disposeEngine()
  }

  @Test(arguments: ["approval_token_consumed", "approval_token_expired", "approval_token_invalid", "pkce_verification_failed", "flow_not_approved", "form_flow_id", "retryable"])
  func clearsOnlyTerminalCompletionFailures(scenario: String) async throws {
    let keychain = MagicKeychain()
    let host = try await magicHarness(scenario: scenario, keychain: keychain)
    try await sendMagic(flow: "signIn")
    await #expect(throws: ClerkAPIError.self) {
      try await Clerk.shared.auth.completeMagicLink(flowId: "sia_magic", approvalToken: "approval_magic")
    }
    #expect(try (keychain.pending() != nil) == (scenario == "retryable"))
    #expect(Clerk.shared.session == nil)
    if scenario == "retryable" {
      _ = try await host.runtime.evaluateJSON("magicScenario = 'success'")
      let result = try await Clerk.shared.auth.completeMagicLink(flowId: "sia_magic", approvalToken: "approval_magic")
      #expect(result.createdSessionId == "sess_magic")
    }
    await Clerk.disposeEngine()
  }

  @Test(arguments: ["signIn", "signUp"])
  func wrongResultKindClearsConsumedFlowWithoutCommittingIdentity(flow: String) async throws {
    let keychain = MagicKeychain()
    let host = try await magicHarness(flow: flow, scenario: "wrong_kind", keychain: keychain)
    try await sendMagic(flow: flow)
    let token = Clerk.shared.identityController.currentDeviceToken
    await #expect(throws: ClerkClientError.self) {
      try await Clerk.shared.auth.completeMagicLink(flowId: flow == "signIn" ? "sia_magic" : "sua_magic", approvalToken: "approval_magic")
    }
    #expect(try keychain.pending() == nil)
    #expect(Clerk.shared.identityController.currentDeviceToken == token)
    #expect(Clerk.shared.session == nil)
    #expect(try await magicRequests(host).count == 3)
    await Clerk.disposeEngine()
  }

  @Test(arguments: ["expired", "invalid", "mismatch", "missing_flow", "missing_approval"])
  func rejectsInvalidPendingFlowOrCallbackBeforeNetwork(scenario: String) async throws {
    let keychain = MagicKeychain()
    let host = try await magicHarness(keychain: keychain, create: false)
    let value: [String: Any] = ["kind": "signIn", "flow_id": "sia_magic", "code_verifier": "legacy-verifier", "created_at": 0, "expires_at": scenario == "expired" ? 1 : Date().addingTimeInterval(600).timeIntervalSince1970 * 1000]
    try keychain.set(scenario == "invalid" ? Data("invalid".utf8) : JSONSerialization.data(withJSONObject: value), forKey: "pendingMagicLinkFlow")
    await #expect(throws: ClerkClientError.self) {
      try await Clerk.shared.auth.completeMagicLink(flowId: scenario == "missing_flow" ? " \n" : (scenario == "mismatch" ? "other" : "sia_magic"), approvalToken: scenario == "missing_approval" ? " " : "approval_magic")
    }
    #expect(try await magicRequests(host).isEmpty)
    #expect(try keychain.hasItem(forKey: "pendingMagicLinkFlow") == !["expired", "invalid"].contains(scenario))
    await Clerk.disposeEngine()
  }

  @Test
  func restoresLegacyVerifierWithoutKindAndEstablishesClientWhenTokenless() async throws {
    let keychain = MagicKeychain()
    let host = try await magicHarness(keychain: keychain, create: false)
    let data = try JSONSerialization.data(withJSONObject: ["code_verifier": "legacy-verifier", "created_at": 0, "expires_at": Date().addingTimeInterval(600).timeIntervalSince1970 * 1000])
    try keychain.set(data, forKey: "pendingMagicLinkFlow")
    let result = try await Clerk.shared.auth.completeMagicLink(flowId: "sia_magic", approvalToken: "approval_magic")
    #expect(result.createdSessionId == "sess_magic")
    #expect(try await magicRequests(host).first?.token == "")
    #expect(Clerk.shared.identityController.currentDeviceToken == "redeemed-magic-token")
    #expect(try keychain.pending() == nil)
    await Clerk.disposeEngine()
  }

  @Test
  func completionDoesNotDeleteNewerVerifier() async throws {
    let keychain = MagicKeychain()
    let host = try await magicHarness(scenario: "hold", keychain: keychain)
    try await sendMagic(flow: "signIn")
    let task = Task { try await Clerk.shared.auth.completeMagicLink(flowId: "sia_magic", approvalToken: "approval_magic") }
    try await waitForMagicRedeem(host)
    let replacement = try JSONSerialization.data(withJSONObject: ["kind": "signIn", "flow_id": "new_flow", "code_verifier": "new_verifier", "created_at": 0, "expires_at": Date().addingTimeInterval(600).timeIntervalSince1970 * 1000])
    try keychain.set(replacement, forKey: "pendingMagicLinkFlow")
    _ = try await host.runtime.evaluateJSON("releaseMagicRedeem()")
    _ = try await task.value
    #expect(try keychain.data(forKey: "pendingMagicLinkFlow") == replacement)
    await Clerk.disposeEngine()
  }

  @Test(arguments: ["reconfigure", "identity_change", "clear"])
  func rejectsSupersededIdentityDuringRedemption(scenario: String) async throws {
    let keychain = MagicKeychain()
    let host = try await magicHarness(scenario: scenario == "clear" ? "clear" : "hold", keychain: keychain)
    try await sendMagic(flow: "signIn")
    let task = Task { try await Clerk.shared.auth.completeMagicLink(flowId: "sia_magic", approvalToken: "approval_magic") }
    if scenario != "clear" {
      try await waitForMagicRedeem(host)
      if scenario == "reconfigure" {
        try await Clerk.reconfigure(publishableKey: "pk_test_" + Data("other.clerk.accounts.dev$".utf8).base64EncodedString())
      } else {
        Clerk.shared.identityController.fenceClientResponses()
        _ = try await host.runtime.evaluateJSON("releaseMagicRedeem()")
      }
    }
    await #expect(throws: (any Error).self) { try await task.value }
    #expect(Clerk.shared.session == nil)
    if scenario == "clear" { #expect(Clerk.shared.identityController.currentDeviceToken == nil) }
    await Clerk.disposeEngine()
  }

  @Test
  func identityPersistenceFailureStopsTicketExchangeAndActivation() async throws {
    let keychain = MagicKeychain()
    let host = try await magicHarness(keychain: keychain)
    try await sendMagic(flow: "signIn")
    keychain.rejectIdentityWrites.setValue(true)
    await #expect(throws: (any Error).self) {
      try await Clerk.shared.auth.completeMagicLink(flowId: "sia_magic", approvalToken: "approval_magic")
    }
    #expect(Clerk.shared.session == nil)
    #expect(try await magicRequests(host).contains { $0.body["strategy"] == "ticket" } == false)
    keychain.rejectIdentityWrites.setValue(false)
    await Clerk.disposeEngine()
  }

  @Test
  func restoresPendingFlowAcrossRuntimeReplacementWithoutPersistingOwner() async throws {
    let keychain = MagicKeychain()
    _ = try await magicHarness(keychain: keychain)
    let owner = try #require(Clerk.shared.registerAuthFlow())
    try await AuthFlowRequestScope.withOwner(owner.id) { try await sendMagic(flow: "signIn") }
    let stored = try #require(try keychain.string(forKey: "pendingMagicLinkFlow"))
    #expect(!stored.contains(owner.id.uuidString))
    await Clerk.disposeEngine()
    _ = try await magicHarness(keychain: keychain, create: false)
    let result = try await Clerk.shared.auth.completeMagicLink(flowId: "sia_magic", approvalToken: "approval_magic")
    #expect(result.createdSessionId == "sess_magic")
    #expect(Clerk.shared.isAuthFlowComplete)
    withExtendedLifetime(owner) {}
    await Clerk.disposeEngine()
  }

  @Test
  func publicURLHandlingDeduplicatesConcurrentCallbacks() async throws {
    let host = try await magicHarness(scenario: "hold")
    try await sendMagic(flow: "signIn")
    let url = try magicURL(flowId: "sia_magic")
    let first = Task { try await Clerk.shared.handle(url) }
    try await waitForMagicRedeem(host)
    let second = Task { try await Clerk.shared.handle(url) }
    await Task.yield()
    _ = try await host.runtime.evaluateJSON("releaseMagicRedeem()")
    #expect(try await first.value)
    #expect(try await second.value)
    #expect(try await magicRequests(host).filter { $0.path.hasSuffix("magic_links/complete") }.count == 1)
    await Clerk.disposeEngine()
  }
}

private struct MagicPending: Decodable {
  var kind: String?
  var flowId: String?
  var codeVerifier: String
  var createdAt: Double
  var expiresAt: Double
}

private final class MagicKeychain: KeychainStorage, @unchecked Sendable {
  let backing = InMemoryKeychain()
  let rejectPendingWrites = LockIsolated(false)
  let rejectIdentityWrites = LockIsolated(false)
  func set(_ data: Data, forKey key: String) throws {
    if key == "pendingMagicLinkFlow", rejectPendingWrites.value { throw KeychainError.unexpectedStatus(-50) }
    if key != "pendingMagicLinkFlow", rejectIdentityWrites.value { throw KeychainError.unexpectedStatus(-50) }
    try backing.set(data, forKey: key)
  }

  func data(forKey key: String) throws -> Data? {
    try backing.data(forKey: key)
  }

  func deleteItem(forKey key: String) throws {
    try backing.deleteItem(forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    try backing.hasItem(forKey: key)
  }

  func pending() throws -> MagicPending? {
    guard let data = try data(forKey: "pendingMagicLinkFlow") else { return nil }
    let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(MagicPending.self, from: data)
  }
}

private struct MagicRequest: Decodable {
  var path: String
  var body: [String: String]
  var token: String
}

@MainActor
private func magicRequests(_ host: ClerkJSHost) async throws -> [MagicRequest] {
  try await JSONDecoder().decode([MagicRequest].self, from: Data(host.runtime.evaluateJSON("magicRequests").utf8))
}

@MainActor
private func sendMagic(flow: String) async throws {
  if flow == "signIn" { try await Clerk.requireEngineSignIn().sendEmailLink() }
  else { try await Clerk.requireEngineSignUp().sendEmailLink() }
}

private func magicURL(flowId: String) throws -> URL {
  try #require(URL(string: "myapp://callback?flow_id=\(flowId)&approval_token=approval_magic"))
}

private func magicChallenge(_ verifier: String) -> String {
  Data(SHA256.hash(data: Data(verifier.utf8))).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
}

@MainActor
private func waitForMagicRedeem(_ host: ClerkJSHost) async throws {
  for _ in 0 ..< 100 {
    if try await host.runtime.evaluateJSON("typeof releaseMagicRedeem === 'function'") == "true" { return }
    try await Task.sleep(for: .milliseconds(10))
  }
  throw ClerkClientError(message: "Magic link request did not start")
}

@MainActor
private func magicHarness(flow: String = "signIn", scenario: String = "success", keychain: MagicKeychain = .init(), create: Bool = true) async throws -> ClerkJSHost {
  let host = try await configureEmbeddedClerkForTesting(signedIn: false) { clerk in
    clerk.dependencies = MockDependencyContainer(keychain: keychain)
    try clerk.dependencies.configurationManager.configure(publishableKey: testPublishableKey, options: .init(redirectConfig: .init(redirectUrl: "myapp://callback")))
  }
  let settings = try String(decoding: JSONEncoder().encode(["flow": flow, "scenario": scenario]), as: UTF8.self)
  let fixture = try String(decoding: ClerkJSHost.snapshotSignedInClient(), as: UTF8.self)
  _ = try await host.runtime.evaluateJSON("""
    (function() {
      var settings = \(settings);
      globalThis.magicScenario = settings.scenario;
      globalThis.magicRequests = [];
      var client = \(fixture);
      client.id = 'client_magic';
      var session = client.sessions[0];
      session.id = 'sess_magic';
      session.expire_at = Date.now() + 3600000;
      session.abandon_at = Date.now() + 86400000;
      session.last_active_token.jwt = btoa(JSON.stringify({alg:'RS256'})).replace(/=+$/, '') + '.' + btoa(JSON.stringify({sub:'user_fixture',sid:'sess_magic',iat:Math.floor(Date.now()/1000),exp:Math.floor(Date.now()/1000)+3600})).replace(/=+$/, '') + '.sig';
      client.sessions = [];
      client.last_active_session_id = null;
      var signIn = {object:'sign_in',id:'sia_magic',status:'needs_first_factor',identifier:'ada@example.com',supported_identifiers:['email_address'],
        supported_first_factors:[{strategy:'email_link',email_address_id:'ema_other',safe_identifier:'other@example.com'},{strategy:'email_link',email_address_id:'ema_match',safe_identifier:'ada@example.com'}],
        supported_second_factors:[],first_factor_verification:{status:'unverified',strategy:'email_link'},second_factor_verification:null,user_data:{},created_session_id:null};
      var signUp = {object:'sign_up',id:'sua_magic',status:'missing_requirements',required_fields:[],optional_fields:[],missing_fields:['first_name'],unverified_fields:[],verifications:{email_address:{status:'unverified',strategy:'email_link'}},created_session_id:null};
      client.sign_in = signIn; client.sign_up = signUp;
      globalThis.fetch = async function(url, options) {
        var body = Object.fromEntries(new URLSearchParams(options.body || ''));
        magicRequests.push({path:url.pathname,body:body,token:options.headers.get('authorization') || ''});
        var headers = new Headers();
        var response;
        if (url.pathname.includes('/prepare_')) {
          globalThis.magicSavedAtPrepare = await __clerkNativeStorage(JSON.stringify({operation:'read',key:'pendingMagicLinkFlow'}));
          if (magicScenario === 'prepare_failure') return {status:422,ok:false,headers,json:async () => ({errors:[{code:'prepare_failed',message:'Prepare failed'}]})};
          response = settings.flow === 'signIn' ? signIn : signUp;
        } else if (url.pathname.endsWith('/magic_links/complete')) {
          if (magicScenario === 'hold') await new Promise(resolve => { globalThis.releaseMagicRedeem = resolve; });
          if (['approval_token_consumed','approval_token_expired','approval_token_invalid','pkce_verification_failed','flow_not_approved','form_flow_id','retryable'].includes(magicScenario)) {
            return {status:422,ok:false,headers,json:async () => ({errors:[{code:magicScenario === 'form_flow_id' ? 'form_param_value_invalid' : magicScenario,message:'Redeem failed',meta:{param_name:'flow_id'}}]})};
          }
          headers.set('authorization',magicScenario === 'clear' ? '' : 'redeemed-magic-token');
          if (settings.flow === 'signUp') {
            signUp.status = magicScenario === 'incomplete' ? 'missing_requirements' : 'complete';
            signUp.created_session_id = signUp.status === 'complete' ? session.id : null;
            if (signUp.created_session_id) client.sessions = [session];
          }
          response = (settings.flow === 'signUp') !== (magicScenario === 'wrong_kind') ? signUp : {flow_id:body.flow_id,ticket:'ticket_magic'};
        } else if (url.pathname.endsWith('/sign_ins') || url.pathname.endsWith('/sign_ups')) {
          response = url.pathname.endsWith('/sign_ins') ? signIn : signUp;
          if (body.strategy === 'ticket') {
            signIn.status = magicScenario === 'incomplete' ? 'needs_second_factor' : 'complete';
            signIn.created_session_id = signIn.status === 'complete' ? session.id : null;
            if (signIn.created_session_id) client.sessions = [session];
          } else headers.set('authorization','magic-client-token');
        } else if (url.pathname.endsWith('/touch')) { response = session; }
        else throw new Error('Unexpected magic link request ' + url.pathname);
        return {status:200,ok:true,headers,json:async () => ({response,client})};
      };
      return true;
    })()
    """)
  if create {
    _ = try await host.invoke(.init(receiver: .clerk, method: flow == "signIn" ? "createNativeSignIn" : "createNativeSignUp", arguments: [.object(["identifier": .string("ada@example.com")])]))
  }
  return host
}
#endif
