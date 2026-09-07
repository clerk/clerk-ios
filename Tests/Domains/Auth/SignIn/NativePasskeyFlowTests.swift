#if !os(watchOS) && !os(tvOS)
import ClerkJSCore
@testable import ClerkKit
import ClerkSnapshots
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct NativePasskeyFlowTests {
  @Test(arguments: ["needs_first_factor", "needs_second_factor", "needs_client_trust"], [false, true])
  func usesAdvertisedFactorAndPreservesCredentialOptions(status: String, autofill: Bool) async throws {
    let host = try await passkeyHarness(status: status)
    let result = try await Clerk.requireEngineSignIn().authenticateWithPasskey(
      autofill: autofill, preferImmediatelyAvailableCredentials: false
    )
    #expect(result.status == .complete)
    let state = try await passkeyState(host)
    let second = status != "needs_first_factor"
    #expect(state.requests.count == 3)
    #expect(state.requests[1].path.hasSuffix(second ? "/prepare_second_factor" : (autofill ? "/sign_ins" : "/prepare_first_factor")))
    #expect(state.requests[2].path.hasSuffix(second ? "/attempt_second_factor" : "/attempt_first_factor"))
    #expect(state.requests[2].body["strategy"] == "passkey")
    let credential = try #require(state.requests[2].body["public_key_credential"])
    let json = try #require(JSONSerialization.jsonObject(with: Data(credential.utf8)) as? [String: Any])
    #expect(json["id"] as? String == "Y3JlZGVudGlhbA")
    #expect((json["response"] as? [String: Any])?["signature"] as? String == "c2ln")
    let options = try #require(state.credentialOptions.first)
    #expect(options.conditionalUI == (autofill && !second))
    #expect(!options.preferImmediatelyAvailableCredentials)
    #expect(options.challenge == "Y2hhbGxlbmdl")
    #expect(options.rpId == "example.com")
    #expect(options.allowCredentials == ["Y3JlZGVudGlhbA"])
    await Clerk.disposeEngine()
  }

  @Test
  func oneShotStartsDiscoverablePasskeyAttempt() async throws {
    let host = try await passkeyHarness(status: "needs_first_factor")
    let result = try await Clerk.shared.auth.signInWithPasskey()
    #expect(result.status == .complete)
    let state = try await passkeyState(host)
    #expect(state.requests[1].path.hasSuffix("/sign_ins"))
    #expect(state.requests[1].body["strategy"] == "passkey")
    #expect(state.credentialOptions.first?.conditionalUI == false)
    #expect(state.credentialOptions.first?.preferImmediatelyAvailableCredentials == true)
    await Clerk.disposeEngine()
  }

  @Test(arguments: ["needs_first_factor", "needs_second_factor"], ["prepare", "authorize", "attempt"])
  func reportsSharedFailureStage(status: String, failure: String) async throws {
    let host = try await passkeyHarness(status: status, failure: failure)
    let second = status == "needs_second_factor"
    let expected: PasskeyAuthenticationFailure.Stage = failure == "authorize" ? .requestingAuthorization
      : (failure == "prepare" ? (second ? .preparingSecondFactor : .preparingFirstFactor)
        : (second ? .attemptingSecondFactor : .attemptingFirstFactor))
    do {
      try await Clerk.requireEngineSignIn().authenticateWithPasskeyWithFailureContext()
      Issue.record("Expected passkey authentication to fail")
    } catch let error as PasskeyAuthenticationFailure {
      #expect(error.stage == expected)
      if failure != "authorize" {
        #expect((error.underlyingError as? ClerkAPIError)?.code == "passkey_failed")
      }
    }
    let state = try await passkeyState(host)
    if failure == "prepare" { #expect(state.credentialOptions.isEmpty) }
    if failure == "authorize" { #expect(!state.requests.contains { $0.path.contains("attempt_") }) }
    await Clerk.disposeEngine()
  }

  @Test
  func doesNotSubmitCredentialAfterAttemptChangesDuringAuthorization() async throws {
    let host = try await passkeyHarness(status: "needs_first_factor", failure: "supersede")
    await #expect(throws: ClerkClientError.self) {
      try await Clerk.requireEngineSignIn().authenticateWithPasskey()
    }
    let state = try await passkeyState(host)
    #expect(!state.requests.contains { $0.path.contains("attempt_") })
    #expect(Clerk.shared.auth.currentSignIn?.id == "sign_in_replacement")
    await Clerk.disposeEngine()
  }

  @Test
  func rejectsSupersededSignInBeforeCredentialCollection() async throws {
    let host = try await passkeyHarness(status: "needs_first_factor")
    let stale = SignIn(id: "old_sign_in", status: .needsFirstFactor)
    await #expect(throws: ClerkClientError.self) { try await stale.authenticateWithPasskey() }
    #expect(try await passkeyState(host).requests.count == 1)
    #expect(try await passkeyState(host).credentialOptions.isEmpty)
    await Clerk.disposeEngine()
  }
}

private struct PasskeyFlowState: Decodable {
  struct Request: Decodable { var path: String; var body: [String: String] }
  struct Options: Decodable {
    var conditionalUI: Bool
    var preferImmediatelyAvailableCredentials: Bool
    var challenge: String
    var rpId: String
    var allowCredentials: [String]
  }

  var requests: [Request]
  var credentialOptions: [Options]
}

@MainActor
private func passkeyState(_ host: ClerkJSHost) async throws -> PasskeyFlowState {
  try await JSONDecoder().decode(PasskeyFlowState.self, from: Data(host.runtime.evaluateJSON("passkeyFlowState").utf8))
}

@MainActor
private func passkeyHarness(status: String, failure: String = "") async throws -> ClerkJSHost {
  let host = try await configureEmbeddedClerkForTesting()
  let settings = try String(decoding: JSONEncoder().encode(["status": status, "failure": failure]), as: UTF8.self)
  _ = try await host.runtime.evaluateJSON("""
    (function() {
      var settings = \(settings);
      var second = settings.status !== 'needs_first_factor';
      var signIn = {
        object: 'sign_in', id: 'sign_in_passkey', status: settings.status,
        supported_identifiers: ['email_address'], identifier: 'ada@example.com',
        supported_first_factors: [{strategy:'passkey'}],
        supported_second_factors: second ? [{strategy:'passkey'}] : [],
        first_factor_verification: {status:'unverified',strategy:'passkey'},
        second_factor_verification: {status:'unverified',strategy:'passkey'},
        created_session_id: null, user_data: {}
      };
      var count = 0;
      globalThis.passkeyFlowState = {requests:[],credentialOptions:[]};
      globalThis.fetch = async function(url, options) {
        count++;
        var body = Object.fromEntries(new URLSearchParams(options.body || ''));
        passkeyFlowState.requests.push({path:url.pathname,body:body});
        if (body.identifier === 'replacement@example.com') signIn.id = 'sign_in_replacement';
        var prepare = url.pathname.includes('prepare_') || (count > 1 && url.pathname.endsWith('/sign_ins'));
        var attempt = url.pathname.includes('attempt_');
        if ((prepare && settings.failure === 'prepare') || (attempt && settings.failure === 'attempt')) {
          return {status:422,ok:false,headers:new Headers(),json:async () => ({errors:[{code:'passkey_failed',message:'Passkey failed'}]})};
        }
        if (prepare) {
          signIn[second ? 'second_factor_verification' : 'first_factor_verification'].nonce = JSON.stringify({
            challenge:'Y2hhbGxlbmdl',rpId:'example.com',allowCredentials:[{id:'Y3JlZGVudGlhbA',type:'public-key'}]
          });
        }
        if (attempt) { signIn.status = 'complete'; signIn.created_session_id = 'sess_fixture'; }
        return {status:200,ok:true,headers:new Headers(),json:async () => ({response:signIn})};
      };
      ClerkEmbedded.installPasskeyHooks(__clerkInstance, {
        createPublicCredentials: async function() { throw new Error('Unexpected registration'); },
        getPublicCredentials: async function(payload) {
          passkeyFlowState.credentialOptions.push(JSON.parse(payload));
          if (settings.failure === 'supersede') await __clerkInstance.client.signIn.create({identifier:'replacement@example.com'});
          if (settings.failure === 'authorize') throw {code:'passkey_retrieval_cancelled',message:'Cancelled'};
          return {id:'Y3JlZGVudGlhbA',rawId:'Y3JlZGVudGlhbA',type:'public-key',response:{
            clientDataJSON:'Y2xpZW50',authenticatorData:'YXV0aA',signature:'c2ln',userHandle:'dXNlcg'
          }};
        }
      });
      return true;
    })()
    """)
  _ = try await host.invoke(.init(receiver: .clerk, method: "createNativeSignIn", arguments: [.object(["identifier": .string("ada@example.com")])]))
  return host
}
#endif
