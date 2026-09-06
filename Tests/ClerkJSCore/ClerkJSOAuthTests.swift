#if !os(watchOS)
import AuthenticationServices
@testable import ClerkJSCore
import Foundation
import Testing

private let mockPublishableKey = "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk"

struct ClerkJSOAuthTests {
  @Test
  func callbackSchemeRejectsHTTPRedirects() throws {
    let https = try #require(URL(string: "https://example.com/sso-callback"))
    #expect(ClerkJSOAuthSession.callbackScheme(from: https) == nil)
    let custom = try #require(URL(string: "clerktest://sso-callback"))
    #expect(ClerkJSOAuthSession.callbackScheme(from: custom) == "clerktest")
  }

  @Test
  func parseOpenURLAcceptsHTTPSProvider() throws {
    let url = try ClerkJSOAuthSession.parseOpenURL("https://accounts.example.com/oauth?state=1").get()
    #expect(url.host == "accounts.example.com")
  }

  @Test
  func parseOpenURLRejectsCustomSchemeProvider() {
    let result = ClerkJSOAuthSession.parseOpenURL("clerktest://not-a-provider")
    guard case .failure(let error) = result else {
      Issue.record("Expected parse failure")
      return
    }
    #expect(error.code == "oauth_invalid_url")
  }

  @Test
  func allowedRedirectProtocolIncludesColon() throws {
    let url = try #require(URL(string: "clerktest://sso-callback"))
    #expect(ClerkJSRuntime.oauthAllowedRedirectProtocol(from: url) == "clerktest:")
  }

  @Test
  func mapsCanceledLoginToOAuthCancelled() {
    let error = ClerkJSOAuthError.from(ASWebAuthenticationSessionError(.canceledLogin))
    #expect(error.code == "oauth_cancelled")
  }

  @Test
  func openHandsURLAndReturnsCallback() async throws {
    let redirect = try #require(URL(string: "clerktest://sso-callback"))
    let provider = try #require(URL(string: "https://accounts.example.com/oauth"))
    let callback = try #require(URL(string: "clerktest://sso-callback?rotating_token_nonce=abc"))
    let probe = SessionProbe()
    let oauth = ClerkJSOAuthSession(redirectURL: redirect) { url, scheme, handler in
      probe.url = url
      probe.scheme = scheme
      return StubWebAuthenticationSession(
        url: url,
        callbackURLScheme: scheme,
        completionHandler: handler,
        startResult: true,
        onStart: { $0.complete(with: callback, error: nil) }
      )
    }
    let handed = try await oauth.open(href: provider.absoluteString).get()
    #expect(handed == callback.absoluteString)
    #expect(probe.url == provider)
    #expect(probe.scheme == "clerktest")
  }

  @Test
  func openRejectsWhenStartFails() async throws {
    let redirect = try #require(URL(string: "clerktest://sso-callback"))
    let oauth = ClerkJSOAuthSession(redirectURL: redirect) { url, scheme, handler in
      StubWebAuthenticationSession(
        url: url,
        callbackURLScheme: scheme,
        completionHandler: handler,
        startResult: false
      )
    }
    let result = await oauth.open(href: "https://accounts.example.com/oauth")
    guard case .failure(let error) = result else {
      Issue.record("Expected start failure")
      return
    }
    #expect(error.code == "oauth_session_failed")
  }

  @Test
  func openRejectsHTTPRedirectURL() async throws {
    let redirect = try #require(URL(string: "https://example.com/sso-callback"))
    let oauth = ClerkJSOAuthSession(redirectURL: redirect)
    let result = await oauth.open(href: "https://accounts.example.com/oauth")
    guard case .failure(let error) = result else {
      Issue.record("Expected invalid redirect")
      return
    }
    #expect(error.code == "oauth_invalid_redirect")
  }

  @Test
  func transportIsInstalledOnClerkInstance() async throws {
    let redirect = try #require(URL(string: "clerktest://sso-callback"))
    let runtime = ClerkJSRuntime(oauthRedirectURL: redirect)
    let payload = try await decodeTransportProbe(
      runtime.evaluateJSON(
        """
        (async function() {
          var clerk = new Clerk('\(mockPublishableKey)');
          var transport = \(ClerkJSRuntime.oauthTransportInstallSource(redirectURL: redirect));
          return {
            getRedirectUrlType: typeof transport.getRedirectUrl,
            openType: typeof transport.open,
            redirectUrl: transport.getRedirectUrl(),
            clerkType: typeof clerk
          };
        })()
        """
      )
    )
    #expect(payload.getRedirectUrlType == "function")
    #expect(payload.openType == "function")
    #expect(payload.redirectUrl == "clerktest://sso-callback")
    #expect(payload.clerkType == "object")
  }

  @Test
  func transportOpenHandsURLToNativeSession() async throws {
    let redirect = try #require(URL(string: "clerktest://sso-callback"))
    let provider = "https://accounts.example.com/oauth"
    let callback = "clerktest://sso-callback?rotating_token_nonce=abc"
    let runtime = ClerkJSRuntime(oauthRedirectURL: redirect)
    let probe = SessionProbe()
    runtime.oauthSession.sessionFactory = { url, scheme, handler in
      probe.url = url
      probe.scheme = scheme
      return StubWebAuthenticationSession(
        url: url,
        callbackURLScheme: scheme,
        completionHandler: handler,
        startResult: true,
        onStart: { session in
          session.complete(with: URL(string: callback), error: nil)
        }
      )
    }
    let payload = try await decodeOpenResult(
      runtime.evaluateJSON(
        """
        (async function() {
          var transport = \(ClerkJSRuntime.oauthTransportInstallSource(redirectURL: redirect));
          return await transport.open(new URL('\(provider)'));
        })()
        """
      )
    )
    #expect(payload.callbackUrl == callback)
    #expect(probe.url?.absoluteString == provider)
    #expect(probe.scheme == "clerktest")
  }

  @Test
  func transportOpenRejectsCancellation() async throws {
    let redirect = try #require(URL(string: "clerktest://sso-callback"))
    let runtime = ClerkJSRuntime(oauthRedirectURL: redirect)
    runtime.oauthSession.sessionFactory = { url, scheme, handler in
      StubWebAuthenticationSession(
        url: url,
        callbackURLScheme: scheme,
        completionHandler: handler,
        startResult: true,
        onStart: { session in
          session.complete(with: nil, error: ASWebAuthenticationSessionError(.canceledLogin))
        }
      )
    }
    let payload = try await decodeThrown(
      runtime.evaluateJSON(
        """
        (async function() {
          var transport = \(ClerkJSRuntime.oauthTransportInstallSource(redirectURL: redirect));
          try {
            await transport.open(new URL('https://accounts.example.com/oauth'));
            return { threw: false, code: '', message: '' };
          } catch (error) {
            return {
              threw: true,
              code: error && error.code ? String(error.code) : '',
              message: String(error.message || error)
            };
          }
        })()
        """
      )
    )
    #expect(payload.threw)
    #expect(payload.code == "oauth_cancelled")
  }

  @Test
  func nativeOpenRejectsNonHTTPURL() async throws {
    let runtime = ClerkJSRuntime()
    let payload = try await decodeThrown(
      runtime.evaluateJSON(
        """
        (async function() {
          try {
            await __clerkNativeOAuthOpen('javascript:alert(1)');
            return { threw: false, code: '', message: '' };
          } catch (error) {
            return {
              threw: true,
              code: error && error.code ? String(error.code) : '',
              message: String(error.message || error)
            };
          }
        })()
        """
      )
    )
    #expect(payload.threw)
    #expect(payload.code == "oauth_invalid_url")
  }
}

private final class SessionProbe: @unchecked Sendable {
  var url: URL?
  var scheme: String?
}

private final class StubWebAuthenticationSession: ASWebAuthenticationSession {
  private let completionHandler: ASWebAuthenticationSession.CompletionHandler
  private let startResult: Bool
  private let onStart: (StubWebAuthenticationSession) -> Void

  init(
    url: URL,
    callbackURLScheme: String?,
    completionHandler: @escaping ASWebAuthenticationSession.CompletionHandler,
    startResult: Bool,
    onStart: @escaping (StubWebAuthenticationSession) -> Void = { _ in }
  ) {
    self.completionHandler = completionHandler
    self.startResult = startResult
    self.onStart = onStart
    super.init(
      url: url,
      callbackURLScheme: callbackURLScheme,
      completionHandler: completionHandler
    )
  }

  override func start() -> Bool {
    onStart(self)
    return startResult
  }

  override func cancel() {}

  func complete(with url: URL?, error: (any Error)?) {
    completionHandler(url, error)
  }
}

private struct TransportProbe: Decodable {
  var getRedirectUrlType: String
  var openType: String
  var redirectUrl: String
  var clerkType: String
}

private struct OpenResult: Decodable {
  var callbackUrl: String
}

private struct Thrown: Decodable {
  var threw: Bool
  var code: String
  var message: String
}

private func decodeTransportProbe(_ json: String) throws -> TransportProbe {
  try JSONDecoder().decode(TransportProbe.self, from: Data(json.utf8))
}

private func decodeOpenResult(_ json: String) throws -> OpenResult {
  try JSONDecoder().decode(OpenResult.self, from: Data(json.utf8))
}

private func decodeThrown(_ json: String) throws -> Thrown {
  try JSONDecoder().decode(Thrown.self, from: Data(json.utf8))
}
#endif
