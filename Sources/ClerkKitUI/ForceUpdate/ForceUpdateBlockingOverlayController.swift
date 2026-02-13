//
//  ForceUpdateBlockingOverlayController.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import Foundation
import SwiftUI

@MainActor
final class ForceUpdateBlockingOverlayController: ObservableObject {
  static let shared = ForceUpdateBlockingOverlayController()

  @Published private(set) var status: Clerk.ForceUpdateStatus?

  private init() {}

  func update(with status: Clerk.ForceUpdateStatus) {
    self.status = status.isSupported ? nil : status
  }
}

#endif
