//
//  ClerkAuthResponseDecoder.swift
//  Clerk
//

import Foundation

enum ClerkAuthResponseDecoder {
  static func decodeEvent(from data: Data) -> AuthEvent? {
    guard let responseObject = try? JSONDecoder.clerkDecoder.decode(ResponseEnvelope.self, from: data).response.object else {
      return nil
    }

    switch responseObject {
    case .signUp:
      guard let signUp = try? JSONDecoder.clerkDecoder.decode(ClientResponse<SignUp>.self, from: data).response,
            signUp.status == .complete
      else {
        return nil
      }
      return .signUpCompleted(signUp: signUp)
    case .signIn:
      guard let signIn = try? JSONDecoder.clerkDecoder.decode(ClientResponse<SignIn>.self, from: data).response,
            signIn.status == .complete
      else {
        return nil
      }
      return .signInCompleted(signIn: signIn)
    case .session:
      guard let session = try? JSONDecoder.clerkDecoder.decode(ClientResponse<Session>.self, from: data).response,
            session.status == .removed
      else {
        return nil
      }
      return .signedOut(session: session)
    case .other:
      return nil
    }
  }

  static func decodeCompletedAuthFlow(from data: Data) -> TransferFlowResult? {
    switch decodeEvent(from: data) {
    case .signInCompleted(let signIn):
      .signIn(signIn)
    case .signUpCompleted(let signUp):
      .signUp(signUp)
    default:
      nil
    }
  }
}

extension ClerkAuthResponseDecoder {
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
}
