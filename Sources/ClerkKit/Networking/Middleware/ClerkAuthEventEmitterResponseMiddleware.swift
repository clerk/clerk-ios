//
//  ClerkAuthEventEmitterResponseMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkAuthEventEmitterResponseMiddleware: ClerkAsyncResponseMiddleware {
  func validate(_: HTTPURLResponse, data: Data, for _: URLRequest) async throws {
    let signIn = try? JSONDecoder.clerkDecoder.decode(ClientResponse<SignIn>.self, from: data).response
    let signUp = try? JSONDecoder.clerkDecoder.decode(ClientResponse<SignUp>.self, from: data).response
    let session = try? JSONDecoder.clerkDecoder.decode(ClientResponse<Session>.self, from: data).response

    await MainActor.run {
      if let signIn, signIn.status == .complete {
        Clerk.shared.auth.send(.signInCompleted(signIn: signIn))
      }

      if let signUp, signUp.status == .complete {
        Clerk.shared.auth.send(.signUpCompleted(signUp: signUp))
      }

      if let session, session.status == .removed {
        Clerk.shared.auth.send(.signedOut(session: session))
      }
    }
  }
}
