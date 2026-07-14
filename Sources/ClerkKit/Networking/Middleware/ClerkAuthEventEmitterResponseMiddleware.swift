//
//  ClerkAuthEventEmitterResponseMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkAuthEventEmitterResponseMiddleware: ClerkResponseMiddleware {
  private let runtimeScope: ClerkRuntimeScope

  init(runtimeScope: ClerkRuntimeScope) {
    self.runtimeScope = runtimeScope
  }

  func validate(_: HTTPURLResponse, data: Data, for _: URLRequest) async throws {
    guard let event = ClerkAuthResponseDecoder.decodeEvent(from: data) else {
      return
    }

    try await runtimeScope.withCurrentClerk {
      $0.auth.send(event)
    }
  }
}
