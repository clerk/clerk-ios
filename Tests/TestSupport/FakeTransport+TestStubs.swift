@testable import ClerkKit
import Foundation

extension FakeTransport {
  /// A default transport whose client refreshes answer with `get`'s result.
  static func answeringClient(_ get: @escaping @MainActor () async throws -> Client?) -> FakeTransport {
    let transport = FakeTransport.mockDefaults()
    transport.stub(ClientAPI.get()) { _ in
      try await ClientResponse(response: get(), client: nil)
    }
    return transport
  }

  /// A default transport whose environment refreshes answer with `get`'s result.
  static func answeringEnvironment(_ get: @escaping @MainActor () async throws -> Clerk.Environment) -> FakeTransport {
    let transport = FakeTransport.mockDefaults()
    transport.stub(EnvironmentAPI.get()) { _ in
      try await get()
    }
    return transport
  }

  /// Answers hosted-auth creation with `create`'s resource, given the request body.
  func stubHostedAuthCreate(_ create: @escaping @MainActor (JSON?) async throws -> HostedAuthResource) {
    stub(HostedAuthAPI.create(params: HostedAuthCreateParams(redirectUrl: "", codeChallenge: "", state: "", mode: nil))) { call in
      try await ClientResponse(response: create(call.body), client: nil)
    }
  }

  /// Answers hosted-auth redemption with `redeem`'s reply, given the request body.
  func stubHostedAuthRedeem(_ redeem: @escaping @MainActor (JSON?) async throws -> Reply<ClientResponse<Client?>>) {
    stubReply(HostedAuthAPI.redeem(params: HostedAuthRedeemParams(rotatingTokenNonce: "", codeVerifier: ""))) { call in
      try await redeem(call.body)
    }
  }

  /// Answers session token requests, with or without a template, with `fetchToken`'s result, given the session id, template, and request params.
  func stubSessionToken(
    _ fetchToken: @escaping @MainActor (_ sessionId: String, _ template: String?, _ params: SessionTokenRequestParams?) async throws -> TokenResource?
  ) {
    let respond: @MainActor (Call) async throws -> TokenResource? = { call in
      let segments = call.path.split(separator: "/").map(String.init)
      let params = call.body.map { body in
        SessionTokenRequestParams(
          organizationId: body["organization_id"]?.stringValue ?? "",
          token: body["token"]?.stringValue,
          forceOrigin: body["force_origin"]?.stringValue
        )
      }
      return try await fetchToken(segments[3], segments.count > 5 ? segments[5] : nil, params)
    }
    stub(SessionAPI.fetchToken(sessionId: FakeTransport.anyPathSegment, template: nil, params: nil), respond: respond)
    stub(SessionAPI.fetchToken(sessionId: FakeTransport.anyPathSegment, template: FakeTransport.anyPathSegment, params: nil), respond: respond)
  }

  /// Answers session activation without a client update, given the touched session id and the request body.
  func stubSetActive(_ setActive: @escaping @MainActor (_ sessionId: String, _ body: JSON?) async throws -> Void) {
    stub(SessionAPI.touch(sessionId: FakeTransport.anyPathSegment, organizationId: nil)) { call in
      try await setActive(String(call.path.split(separator: "/")[3]), call.body)
      return ClientResponse(response: .mock, client: nil)
    }
  }

  /// Answers sign-up creation with `create`'s sign-up, given the request body.
  func stubSignUpCreate(_ create: @escaping @MainActor (JSON?) async throws -> SignUp) {
    stub(SignUpAPI.create(params: .init())) { call in
      try await ClientResponse(response: create(call.body), client: nil)
    }
  }

  /// Answers sign-in creation with `create`'s sign-in, given the request body.
  func stubSignInCreate(_ create: @escaping @MainActor (JSON?) async throws -> SignIn) {
    stub(SignInAPI.create(params: .init())) { call in
      try await ClientResponse(response: create(call.body), client: nil)
    }
  }

  /// Answers first-factor preparation with `prepare`'s sign-in, given the sign-in id and the request body.
  func stubSignInPrepareFirstFactor(_ prepare: @escaping @MainActor (_ signInId: String, _ body: JSON?) async throws -> SignIn) {
    stub(SignInAPI.prepareFirstFactor(signInId: FakeTransport.anyPathSegment, params: .init(strategy: .emailCode))) { call in
      try await ClientResponse(response: prepare(String(call.path.split(separator: "/")[3]), call.body), client: nil)
    }
  }

  /// Answers first-factor attempts with `attempt`'s sign-in, given the sign-in id and the request body.
  func stubSignInAttemptFirstFactor(_ attempt: @escaping @MainActor (_ signInId: String, _ body: JSON?) async throws -> SignIn) {
    stub(SignInAPI.attemptFirstFactor(signInId: FakeTransport.anyPathSegment, params: .init(strategy: .emailCode))) { call in
      try await ClientResponse(response: attempt(String(call.path.split(separator: "/")[3]), call.body), client: nil)
    }
  }
}
