//
//  ClerkInvalidAuthResponseMiddleware.swift
//  Clerk
//

import Foundation

/// When the API indicates authentication is invalid, re-sync the client state unless we already attempted it.
struct ClerkInvalidAuthResponseMiddleware: ClerkResponseMiddleware {
  func validate(_: HTTPURLResponse, data: Data, for request: URLRequest) throws {
    guard
      let clerkErrorResponse = try? JSONDecoder.clerkDecoder.decode(ClerkErrorResponse.self, from: data),
      let clerkAPIError = clerkErrorResponse.errors.first,
      let code = clerkAPIError.apiCode,
      code == .authenticationInvalid || code == .resourceNotFound
    else {
      return
    }

    if request.url?.lastPathComponent == "client",
       request.httpMethod == "GET"
    {
      return
    }

    Task {
      try await Clerk.shared.refreshClient()
    }
  }
}
