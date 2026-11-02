//
//  ClerkServerClockResponseMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkServerClockResponseMiddleware: ClerkResponseObserver {
  private let runtimeScope: ClerkRuntimeScope

  init(runtimeScope: ClerkRuntimeScope) {
    self.runtimeScope = runtimeScope
  }

  func observe(_ response: HTTPURLResponse, data _: Data, for _: URLRequest) async {
    let receivedAt = Date.now
    guard let serverDate = response.serverDate else { return }
    try? await runtimeScope.withCurrentClerk {
      $0.identityController.recordServerDate(serverDate, receivedAt: receivedAt)
    }
  }
}
