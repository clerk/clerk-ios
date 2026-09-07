#if !os(watchOS) && !os(tvOS)
import AuthenticationServices
@testable import ClerkJSCore
@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct NativeOAuthTests {
  @Test(arguments: [false, true])
  func developmentOAuthOpensNativeBrowserWithoutWindow(signUp: Bool) async throws {
    let host = try await configureEmbeddedClerkForTesting(signedIn: false)
    #expect(try await host.runtime.evaluateJSON("typeof window") == "\"undefined\"")
    _ = try await host.runtime.evaluateJSON("""
      (function() {
        globalThis.oauthRequests = [];
        globalThis.fetch = async function(url, options) {
          oauthRequests.push({ path: url.pathname, body: Object.fromEntries(new URLSearchParams(options.body || '')) });
          var verification = { strategy: 'oauth_google', status: 'unverified', external_verification_redirect_url: 'https://accounts.example.com/oauth' };
          var response = url.pathname.endsWith('/sign_ups')
            ? { object: 'sign_up', id: 'sua_oauth', status: 'missing_requirements', required_fields: [], optional_fields: [], missing_fields: [], unverified_fields: [], verifications: { external_account: verification } }
            : { object: 'sign_in', id: 'sia_oauth', status: 'needs_first_factor', first_factor_verification: verification };
          return { status: 200, ok: true, headers: new Headers(), json: async function() { return { response: response }; } };
        };
        return true;
      })()
      """)
    let probe = OAuthBrowserProbe()
    host.runtime.oauthSession.sessionFactory = { url, scheme, completion in
      probe.url = url
      probe.scheme = scheme
      return CancelledOAuthBrowser(url: url, scheme: scheme, completion: completion)
    }
    do {
      if signUp {
        try await Clerk.shared.auth.signUpWithOAuth(provider: .google)
      } else {
        try await Clerk.shared.auth.signInWithOAuth(provider: .google)
      }
      Issue.record("Expected the native browser cancellation")
    } catch {
      #expect(error.localizedDescription.contains("cancelled"))
    }
    #expect(probe.url?.absoluteString == "https://accounts.example.com/oauth")
    #expect(probe.scheme == ClerkJSRuntime.defaultOAuthRedirectURL.scheme)
    let requestJSON = try await host.runtime.evaluateJSON("oauthRequests")
    let requests = try JSONDecoder().decode([OAuthRequest].self, from: Data(requestJSON.utf8))
    #expect(requests.count == 1)
    #expect(requests.first?.path == (signUp ? "/v1/client/sign_ups" : "/v1/client/sign_ins"))
    #expect(requests.first?.body["strategy"] == "oauth_google")
    #expect(requests.first?.body["redirect_url"] == ClerkJSRuntime.defaultOAuthRedirectURL.absoluteString)
    #expect(requests.first?.body["action_complete_redirect_url"] == ClerkJSRuntime.defaultOAuthRedirectURL.absoluteString)
    await Clerk.disposeEngine()
  }
}

private struct OAuthRequest: Decodable {
  var path: String
  var body: [String: String]
}

private final class OAuthBrowserProbe: @unchecked Sendable {
  var url: URL?
  var scheme: String?
}

private final class CancelledOAuthBrowser: ASWebAuthenticationSession {
  private let completion: ASWebAuthenticationSession.CompletionHandler

  init(url: URL, scheme: String?, completion: @escaping ASWebAuthenticationSession.CompletionHandler) {
    self.completion = completion
    super.init(url: url, callbackURLScheme: scheme, completionHandler: completion)
  }

  override func start() -> Bool {
    completion(nil, ASWebAuthenticationSessionError(.canceledLogin))
    return true
  }

  override func cancel() {}
}
#endif
