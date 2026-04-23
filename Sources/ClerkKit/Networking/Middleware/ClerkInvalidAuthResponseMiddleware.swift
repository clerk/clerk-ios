//
//  ClerkInvalidAuthResponseMiddleware.swift
//  Clerk
//

import Foundation

/// When the API indicates authentication is invalid, re-sync the client state unless we already attempted it.
struct ClerkInvalidAuthResponseMiddleware: ClerkResponseMiddleware {
  let invalidAuthCodes = ["authentication_invalid", "resource_not_found"]
  private let refreshClientAfterInvalidAuth: @Sendable @MainActor () async -> Void

  init(
    refreshClientAfterInvalidAuth: @escaping @Sendable @MainActor () async -> Void = {
      await Clerk.shared.refreshClientAfterInvalidAuth()
    }
  ) {
    self.refreshClientAfterInvalidAuth = refreshClientAfterInvalidAuth
  }

  func validate(_: HTTPURLResponse, data: Data, for request: URLRequest) async throws {
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

    await refreshClientAfterInvalidAuth()
  }
}
