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
}
