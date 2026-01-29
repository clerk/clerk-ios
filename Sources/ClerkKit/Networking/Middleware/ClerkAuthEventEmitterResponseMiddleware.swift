//
//  ClerkAuthEventEmitterResponseMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import Foundation

struct ClerkAuthEventEmitterResponseMiddleware: ClerkResponseMiddleware {
  func validate(_: HTTPURLResponse, data: Data, for _: URLRequest) throws {
    Task { @MainActor in
      if let clientResponse = try? JSONDecoder.clerkDecoder.decode(ClientResponse<SignIn>.self, from: data),
         clientResponse.response.status == .complete
      {
        // Update client first to ensure session is available
        if let client = clientResponse.client {
          Clerk.shared.client = client
        }
        Clerk.shared.auth.send(.signInCompleted(signIn: clientResponse.response))
      }

      if let clientResponse = try? JSONDecoder.clerkDecoder.decode(ClientResponse<SignUp>.self, from: data),
         clientResponse.response.status == .complete
      {
        // Update client first to ensure session is available
        if let client = clientResponse.client {
          Clerk.shared.client = client
        }
        Clerk.shared.auth.send(.signUpCompleted(signUp: clientResponse.response))
      }

      if let session = try? JSONDecoder.clerkDecoder.decode(ClientResponse<Session>.self, from: data).response,
         session.status == .removed
      {
        Clerk.shared.auth.send(.signedOut(session: session))
      }
    }
  }
}
