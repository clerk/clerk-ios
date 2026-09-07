import ClerkSnapshots
import Foundation

extension Clerk {
  @MainActor
  package static func js(_ receiver: ClerkJSReceiver, _ call: some ClerkJSCallable) async throws {
    _ = try await requireEngineClient().invoke(ClerkJSInvocation(receiver, call))
  }

  @MainActor
  package static func js<R: Decodable>(
    _ receiver: ClerkJSReceiver,
    _ call: some ClerkJSCallable,
    as _: R.Type
  ) async throws -> R {
    let payload = try await requireEngineClient().invoke(ClerkJSInvocation(receiver, call))
    return try JSONDecoder.clerkDecoder.decode(R.self, from: payload.data())
  }

  @MainActor
  package static func requireUser() throws -> User {
    guard let user = shared.user else {
      throw ClerkClientError(message: "The JS call did not produce a user.")
    }
    return user
  }

  @MainActor
  package static func requireSession() throws -> Session {
    guard let session = shared.session else {
      throw ClerkClientError(message: "The JS call did not produce a session.")
    }
    return session
  }

  @MainActor
  static func finishedSignIn() async throws -> SignIn {
    let signIn = try requireEngineSignIn()
    if signIn.status == .complete, let sessionId = signIn.createdSessionId {
      try await js(.clerk, ClerkJSCall.setActive(.init(session: .string(sessionId))))
    }
    return signIn
  }

  @MainActor
  static func finishedSignUp() async throws -> SignUp {
    let signUp = try requireEngineSignUp()
    if let sessionId = signUp.createdSessionId {
      try await js(.clerk, ClerkJSCall.setActive(.init(session: .string(sessionId))))
    }
    return signUp
  }
}

extension JSON {
  var jsonValue: JSONValue {
    (try? JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(self))) ?? .null
  }
}
