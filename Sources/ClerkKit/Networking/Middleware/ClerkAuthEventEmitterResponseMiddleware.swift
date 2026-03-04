//
//  ClerkAuthEventEmitterResponseMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkAuthEventEmitterResponseMiddleware: ClerkResponseMiddleware {
  func validate(_: HTTPURLResponse, data: Data, for _: URLRequest) async throws {
    guard let event = authEvent(from: data) else { return }
    await emit(event)
  }

  private func authEvent(from data: Data) -> AuthEvent? {
    if let signIn = try? JSONDecoder.clerkDecoder.decode(ClientResponse<SignIn>.self, from: data).response,
       signIn.status == .complete
    {
      return .signInCompleted(signIn: signIn)
    }

    if let signUp = try? JSONDecoder.clerkDecoder.decode(ClientResponse<SignUp>.self, from: data).response,
       signUp.status == .complete
    {
      return .signUpCompleted(signUp: signUp)
    }

    if let session = try? JSONDecoder.clerkDecoder.decode(ClientResponse<Session>.self, from: data).response,
       session.status == .removed
    {
      return .signedOut(session: session)
    }

    return nil
  }

  @MainActor
  private func emit(_ event: AuthEvent) {
    Clerk.shared.auth.send(event)
  }
}
