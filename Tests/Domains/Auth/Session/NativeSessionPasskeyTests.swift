#if !os(watchOS) && !os(tvOS)
import ClerkJSCore
@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct NativeSessionPasskeyTests {
  @Test(arguments: [false, true], [false, true])
  func verifiesRequestedStageThroughSharedProtocol(second: Bool, immediate: Bool) async throws {
    let host = try await sessionPasskeyHarness()
    let session = try #require(Clerk.shared.session)
    let result = try await session.verifyWithPasskey(
      preferImmediatelyAvailableCredentials: immediate, level: second ? .secondFactor : .firstFactor
    )
    #expect(result.status == .complete)
    #expect(result.session?.id == session.id)
    let requests = try await JSONDecoder().decode([String].self, from: Data(host.runtime.evaluateJSON("sessionPasskeyRequests.map(r => r.path)").utf8))
    #expect(requests == [
      "/v1/client/sessions/sess_fixture/verify/prepare_\(second ? "second" : "first")_factor",
      "/v1/client/sessions/sess_fixture/verify/attempt_\(second ? "second" : "first")_factor",
    ])
    #expect(try await host.runtime.evaluateJSON("sessionPasskeyOptions.preferImmediatelyAvailableCredentials") == String(immediate))
    #expect(try await host.runtime.evaluateJSON("sessionPasskeyOptions.conditionalUI") == "false")
    #expect(try await host.runtime.evaluateJSON("JSON.parse(sessionPasskeyRequests[1].body.public_key_credential).response.signature === 'c2ln'") == "true")
    await Clerk.disposeEngine()
  }

  @Test
  func doesNotAttemptReverificationAfterSessionEndsDuringCredentialCollection() async throws {
    let host = try await sessionPasskeyHarness(endDuringAuthorization: true)
    let session = try #require(Clerk.shared.session)
    await #expect(throws: ClerkClientError.self) { try await session.verifyWithPasskey() }
    #expect(try await host.runtime.evaluateJSON("sessionPasskeyRequests.some(r => r.path.includes('attempt_'))") == "false")
    await Clerk.disposeEngine()
  }
}

@MainActor
private func sessionPasskeyHarness(endDuringAuthorization: Bool = false) async throws -> ClerkJSHost {
  let host = try await configureEmbeddedClerkForTesting()
  _ = try await host.runtime.evaluateJSON("""
    (function() {
      globalThis.sessionPasskeyRequests = [];
      var session = __clerkInstance.session.__internal_toSnapshot();
      var verification = {
        object:'session_verification', id:'sv_test', status:'needs_first_factor',level:'multi_factor',session:session,
        supported_first_factors:[{strategy:'passkey'}],supported_second_factors:[{strategy:'passkey'}],
        first_factor_verification:{status:'unverified',strategy:'passkey'},second_factor_verification:{status:'unverified',strategy:'passkey'}
      };
      globalThis.fetch = async function(url, options) {
        var body = Object.fromEntries(new URLSearchParams(options.body || ''));
        sessionPasskeyRequests.push({path:url.pathname,body:body});
        var response = verification;
        if (url.pathname.endsWith('/end')) { session.status = 'ended'; response = session; }
        else if (url.pathname.includes('prepare_')) {
          verification[url.pathname.includes('second_factor') ? 'second_factor_verification' : 'first_factor_verification'].nonce = JSON.stringify({challenge:'Y2hhbGxlbmdl',rpId:'example.com'});
        } else if (url.pathname.includes('attempt_')) { verification.status = 'complete'; }
        else throw new Error('Unexpected request ' + url.pathname);
        return {status:200,ok:true,headers:new Headers(),json:async () => ({response})};
      };
      ClerkEmbedded.installPasskeyHooks(__clerkInstance, {
        createPublicCredentials: async () => { throw new Error('Unexpected registration'); },
        getPublicCredentials: async payload => {
          globalThis.sessionPasskeyOptions = JSON.parse(payload);
          if (\(endDuringAuthorization)) await __clerkInstance.session.end();
          return {id:'Y3JlZA',rawId:'Y3JlZA',type:'public-key',response:{
            clientDataJSON:'Y2xpZW50',authenticatorData:'YXV0aA',signature:'c2ln',userHandle:'dXNlcg'
          }};
        }
      });
      return true;
    })()
    """)
  return host
}
#endif
