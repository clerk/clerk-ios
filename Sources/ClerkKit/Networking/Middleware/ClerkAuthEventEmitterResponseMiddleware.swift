//
//  ClerkAuthEventEmitterResponseMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkAuthEventEmitterResponseMiddleware: ClerkResponseMiddleware {
  func validate(_: HTTPURLResponse, data: Data, for _: URLRequest) async throws {
    guard let responseObject = Self.decodeResponseObject(from: data) else {
      return
    }

    switch responseObject {
    case .signUp:
      if let signUp = try? JSONDecoder.clerkDecoder.decode(ClientResponse<SignUp>.self, from: data).response,
         signUp.status == .complete
      {
        await Clerk.shared.auth.send(.signUpCompleted(signUp: signUp))
        print("***SIGN UP COMPLETE")
      }
    case .signIn:
      if let signIn = try? JSONDecoder.clerkDecoder.decode(ClientResponse<SignIn>.self, from: data).response,
         signIn.status == .complete
      {
        await Clerk.shared.auth.send(.signInCompleted(signIn: signIn))
        print("***SIGN IN COMPLETE")
      }
    case .session:
      if let session = try? JSONDecoder.clerkDecoder.decode(ClientResponse<Session>.self, from: data).response,
         session.status == .removed
      {
        await Clerk.shared.auth.send(.signedOut(session: session))
        print("***SESSION REMOVED")
      }
    case .other:
      return
    }
  }

  private static func decodeResponseObject(from data: Data) -> ResponseObject? {
    try? JSONDecoder.clerkDecoder.decode(ResponseEnvelope.self, from: data).response.object
  }
}

private struct ResponseEnvelope: Decodable {
  let response: ResponseObjectPayload
}

private struct ResponseObjectPayload: Decodable {
  let object: ResponseObject
}

private enum ResponseObject: String, Decodable {
  case signIn = "sign_in_attempt"
  case signUp = "sign_up_attempt"
  case session
  case other

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    self = ResponseObject(rawValue: rawValue) ?? .other
  }
}
