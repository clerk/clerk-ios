//
//  ClerkInvalidAuthResponseMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 2/14/25.
//

import Foundation

/// When the API indicates authentication is invalid, re-sync the client state unless we already attempted it.
struct ClerkInvalidAuthResponseMiddleware: NetworkResponseMiddleware {
  let invalidAuthCodes = ["authentication_invalid", "resource_not_found"]

  func validate(_: HTTPURLResponse, data: Data, for request: URLRequest) throws {
    guard
      let clerkErrorResponse = try? JSONDecoder.clerkDecoder.decode(ClerkErrorResponse.self, from: data),
      let clerkAPIError = clerkErrorResponse.errors.first,
      invalidAuthCodes.contains(clerkAPIError.code)
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
