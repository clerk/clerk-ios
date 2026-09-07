#if !os(watchOS) && !os(tvOS)
import ClerkJSCore
@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct NativeContinuationTests {
  @Test(arguments: ["email_code", "phone_code", "reset_password_email_code", "reset_password_phone_code"])
  func verifiesCodeUsingLiveSharedStrategy(strategy: String) async throws {
    let host = try await continuationHarness(strategy: strategy)
    let signIn = try Clerk.requireEngineSignIn()
    let result = try await signIn.verifyCode("424242")
    #expect(result.status == (strategy.hasPrefix("reset_") ? .needsNewPassword : .complete))
    let requests = try await continuationRequests(host)
    #expect(requests[1].path == "/v1/client/sign_ins/sia_continuation/attempt_first_factor")
    #expect(requests[1].body["strategy"] == strategy)
    #expect(requests[1].body["code"] == "424242")
    await Clerk.disposeEngine()
  }

  @Test(arguments: ["", "password"])
  func rejectsMissingOrUnsupportedCodeStrategyWithoutRequest(strategy: String) async throws {
    let host = try await continuationHarness(strategy: strategy)
    let signIn = try Clerk.requireEngineSignIn()
    do {
      try await signIn.verifyCode("424242")
      Issue.record("Expected an invalid strategy error")
    } catch let error as ClerkClientError {
      #expect(error.message == (strategy.isEmpty ? "Unable to verify code because no first factor strategy is set." : "Unable to verify code for strategy 'password'."))
    }
    #expect(try await continuationRequests(host).count == 1)
    await Clerk.disposeEngine()
  }

  @Test
  func retainedSnapshotCannotVerifyANewerAttempt() async throws {
    let host = try await continuationHarness(strategy: "email_code")
    let stale = SignIn(id: "sia_old", status: .needsFirstFactor)
    await #expect(throws: ClerkClientError.self) { try await stale.verifyCode("424242") }
    #expect(try await continuationRequests(host).count == 1)
    await Clerk.disposeEngine()
  }

  @Test(arguments: ["signIn", "signUp"], ["nonce%2Bvalue", ""])
  func callbackReloadsNonceWithoutTransferring(flow: String, nonce: String) async throws {
    let host = try await continuationHarness(flow: flow, verificationStatus: "transferable")
    let callback = try #require(URL(string: "myapp://callback?extra=1&rotating_token_nonce=\(nonce)#fragment"))
    let result = try await completeCallback(flow: flow, url: callback)
    if flow == "signIn" { guard case .signIn = result else { Issue.record("Unexpected transfer"); return } }
    else { guard case .signUp = result else { Issue.record("Unexpected transfer"); return } }
    let requests = try await continuationRequests(host)
    #expect(requests.count == 2)
    #expect(requests[1].query["rotating_token_nonce"] == (nonce.isEmpty ? nil : "nonce+value"))
    await Clerk.disposeEngine()
  }

  @Test(arguments: ["signIn", "signUp"])
  func callbackWithoutNonceUsesSharedTransfer(flow: String) async throws {
    let host = try await continuationHarness(flow: flow, verificationStatus: "transferable")
    let result = try await completeCallback(flow: flow, url: #require(URL(string: "myapp://callback")))
    if flow == "signIn" { guard case .signUp = result else { Issue.record("Expected sign-up"); return } }
    else { guard case .signIn = result else { Issue.record("Expected sign-in"); return } }
    let requests = try await continuationRequests(host)
    #expect(requests.count == 3)
    #expect(requests[2].body["transfer"] == "true")
    if flow == "signIn" {
      let metadata = try #require(requests[2].body["unsafe_metadata"])
      #expect(try JSONDecoder().decode([String: String].self, from: Data(metadata.utf8)) == ["plan": "pro"])
    }
    await Clerk.disposeEngine()
  }

  @Test
  func callbackRespectsDisabledTransfer() async throws {
    let host = try await continuationHarness(verificationStatus: "transferable")
    let result = try await Clerk.requireEngineSignIn().completeEnterpriseSSO(callbackURL: #require(URL(string: "myapp://callback")), transferable: false)
    guard case .signIn = result else { Issue.record("Unexpected transfer"); return }
    #expect(try await continuationRequests(host).count == 2)
    await Clerk.disposeEngine()
  }

  @Test(arguments: ["signIn", "signUp"], [false, true])
  func callbackReportsVerificationErrors(flow: String, nonce: Bool) async throws {
    let host = try await continuationHarness(flow: flow, verificationStatus: "failed")
    do {
      try await completeCallback(flow: flow, url: URL(string: "myapp://callback" + (nonce ? "?rotating_token_nonce=test" : ""))!)
      Issue.record("Expected verification error")
    } catch let error as ClerkAPIError { #expect(error.code == "external_verification_failed") }
    #expect(try await continuationRequests(host).count == 2)
    await Clerk.disposeEngine()
  }

  private func completeCallback(flow: String, url: URL) async throws -> TransferFlowResult {
    if flow == "signIn" {
      return try await Clerk.requireEngineSignIn().completeEnterpriseSSO(callbackURL: url, unsafeMetadata: ["plan": "pro"])
    }
    return try await Clerk.requireEngineSignUp().handleRedirectCallbackUrl(url)
  }
}

private struct ContinuationRequest: Decodable {
  var path: String
  var body: [String: String]
  var query: [String: String]
}

@MainActor
private func continuationRequests(_ host: ClerkJSHost) async throws -> [ContinuationRequest] {
  try await JSONDecoder().decode([ContinuationRequest].self, from: Data(host.runtime.evaluateJSON("continuationRequests").utf8))
}

@MainActor
private func continuationHarness(flow: String = "signIn", strategy: String = "oauth_google", verificationStatus: String = "unverified") async throws -> ClerkJSHost {
  let host = try await configureEmbeddedClerkForTesting()
  let settings = try String(decoding: JSONEncoder().encode(["flow": flow, "strategy": strategy, "verificationStatus": verificationStatus]), as: UTF8.self)
  _ = try await host.runtime.evaluateJSON("""
    (function() {
      var settings = \(settings);
      globalThis.continuationRequests = [];
      var verification = {strategy:settings.strategy || null,status:settings.verificationStatus};
      if (settings.verificationStatus === 'failed') verification.error = {code:'external_verification_failed',message:'Verification failed'};
      var signIn = {object:'sign_in',id:'sia_continuation',status:'needs_first_factor',identifier:'ada@example.com',
        supported_identifiers:['email_address'],supported_first_factors:[],supported_second_factors:[],
        first_factor_verification:settings.flow === 'signIn' ? verification : {status:'unverified'},
        second_factor_verification:null,user_data:{},created_session_id:null};
      var signUp = {object:'sign_up',id:'sua_continuation',status:'missing_requirements',required_fields:[],optional_fields:[],missing_fields:['first_name'],unverified_fields:[],
        verifications:{external_account: settings.flow === 'signUp' ? verification : {status:'unverified'}},created_session_id:null};
      globalThis.fetch = async function(url, options) {
        var body = Object.fromEntries(new URLSearchParams(options.body || ''));
        continuationRequests.push({path:url.pathname,body:body,query:Object.fromEntries(url.searchParams)});
        var response = url.pathname.includes('/sign_ups') ? signUp : signIn;
        if (url.pathname.endsWith('/attempt_first_factor')) {
          response.status = settings.strategy.startsWith('reset_') ? 'needs_new_password' : 'complete';
          response.created_session_id = response.status === 'complete' ? 'sess_fixture' : null;
        }
        return {status:200,ok:true,headers:new Headers(),json:async () => ({response})};
      };
      return true;
    })()
    """)
  _ = try await host.invoke(.init(receiver: flow == "signIn" ? .signIn : .signUp, method: "create", arguments: [.object(["emailAddress": .string("ada@example.com")])]))
  return host
}
#endif
