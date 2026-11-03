//
//  ClerkServerClockResponseMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkServerClockResponseMiddleware: ClerkResponseObserver {
  private let runtimeScope: ClerkRuntimeScope
  private let currentDate: @Sendable () -> Date

  init(
    runtimeScope: ClerkRuntimeScope,
    currentDate: @escaping @Sendable () -> Date = { .now }
  ) {
    self.runtimeScope = runtimeScope
    self.currentDate = currentDate
  }

  func observe(_ response: HTTPURLResponse, data _: Data, for _: URLRequest) async {
    let receivedAt = currentDate()
    guard let serverDate = response.serverDate else { return }
    try? await runtimeScope.withCurrentClerk {
      $0.identityController.recordServerDate(serverDate, receivedAt: receivedAt)
    }
  }
}
