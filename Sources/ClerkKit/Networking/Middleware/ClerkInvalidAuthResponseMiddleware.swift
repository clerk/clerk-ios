//
//  ClerkInvalidAuthResponseMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 2/14/25.
//

import Foundation

/// When the API indicates authentication is invalid, re-sync the client state unless we already attempted it.
struct ClerkInvalidAuthResponseMiddleware: NetworkResponseMiddleware {
  func validate(_ response: HTTPURLResponse, data: Data, for request: URLRequest) throws {
    guard
      let clerkErrorResponse = try? JSONDecoder.clerkDecoder.decode(ClerkErrorResponse.self, from: data),
      let clerkAPIError = clerkErrorResponse.errors.first,
      clerkAPIError.code == "authentication_invalid"
    else {
      return
    }

    if request.url?.lastPathComponent == "client",
       request.httpMethod == "GET" {
      return
    }

    Task {
      try await Client.get()
    }
  }
}
