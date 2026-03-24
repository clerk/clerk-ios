//
//  ClerkAuthEventEmitterResponseMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkAuthEventEmitterResponseMiddleware: ClerkResponseMiddleware {
  func validate(_: HTTPURLResponse, data: Data, for _: URLRequest) async throws {
    if let signUp = try? JSONDecoder.clerkDecoder.decode(ClientResponse<SignUp>.self, from: data).response,
       signUp.status == .complete
    {
      await Clerk.shared.auth.send(.signUpCompleted(signUp: signUp))
      print("**SIGN UP HERE**")
      return
    }

    if let signIn = try? JSONDecoder.clerkDecoder.decode(ClientResponse<SignIn>.self, from: data).response,
       signIn.status == .complete
    {
      await Clerk.shared.auth.send(.signInCompleted(signIn: signIn))
      print("**SIGN IN HERE**")
      return
    }

    if let session = try? JSONDecoder.clerkDecoder.decode(ClientResponse<Session>.self, from: data).response,
       session.status == .removed
    {
      await Clerk.shared.auth.send(.signedOut(session: session))
      print("**SIGN OUT HERE**")
    }
  }
}
