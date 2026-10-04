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
}
