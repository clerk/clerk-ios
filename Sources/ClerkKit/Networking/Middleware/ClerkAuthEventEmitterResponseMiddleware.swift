//
//  ClerkAuthEventEmitterResponseMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkAuthEventEmitterResponseMiddleware: ClerkResponseMiddleware {
  private let clerkProvider: @Sendable @MainActor () -> Clerk

  init(clerkProvider: @escaping @Sendable @MainActor () -> Clerk = { Clerk.shared }) {
    self.clerkProvider = clerkProvider
  }

  func validate(_: HTTPURLResponse, data: Data, for _: URLRequest) async throws {
    if let signUp = try? JSONDecoder.clerkDecoder.decode(ClientResponse<SignUp>.self, from: data).response,
       signUp.status == .complete
    {
      let clerk = await clerkProvider()
      await clerk.auth.send(.signUpCompleted(signUp: signUp))
      return
    }

    if let signIn = try? JSONDecoder.clerkDecoder.decode(ClientResponse<SignIn>.self, from: data).response,
       signIn.status == .complete
    {
      let clerk = await clerkProvider()
      await clerk.auth.send(.signInCompleted(signIn: signIn))
      return
    }

    if let session = try? JSONDecoder.clerkDecoder.decode(ClientResponse<Session>.self, from: data).response,
       session.status == .removed
    {
      let clerk = await clerkProvider()
      await clerk.auth.send(.signedOut(session: session))
    }
  }
}
