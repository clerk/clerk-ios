//
//  AuthFlowRegistration.swift
//  Clerk
//

import Foundation

package final class AuthFlowRegistration: Sendable {
  private let unregister: @MainActor @Sendable () -> Void

  package init(unregister: @escaping @MainActor @Sendable () -> Void) {
    self.unregister = unregister
  }

  deinit {
    let unregister = unregister
    Task { @MainActor in
      unregister()
    }
  }
}
