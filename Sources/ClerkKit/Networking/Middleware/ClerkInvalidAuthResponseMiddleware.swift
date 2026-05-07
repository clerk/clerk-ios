//
//  ClerkInvalidAuthResponseMiddleware.swift
//  Clerk
//

import Foundation

/// When the API indicates authentication is invalid, re-sync the client state unless we already attempted it.
struct ClerkInvalidAuthResponseMiddleware: ClerkResponseMiddleware {
  let invalidAuthCodes = ["authentication_invalid", "resource_not_found"]
  private let runtimeScope: ClerkRuntimeScope

  init(runtimeScope: ClerkRuntimeScope = .init()) {
    self.runtimeScope = runtimeScope
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

    let refreshTask = try await runtimeScope.withCurrentClerk {
      $0.startRefreshClientAfterInvalidAuth()
    }
    await refreshTask.value
  }
}
