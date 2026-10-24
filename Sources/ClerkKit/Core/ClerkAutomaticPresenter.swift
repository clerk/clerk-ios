//
//  ClerkAutomaticPresenter.swift
//  Clerk
//

import Foundation

@MainActor
package protocol ClerkAutomaticPresenter: AnyObject {
  func start(clerk: Clerk)
  func stop()
}

enum ClerkAutomaticPresenterLoader {
  /// ClerkKitUI depends on ClerkKit, and Swift packages can't depend on each other in a
  /// cycle, so ClerkKit finds ClerkKitUI's presenter through the Objective-C runtime.
  static let presenterClassName = "ClerkKitUIAutomaticPresenter"

  @MainActor
  static func load() -> (any ClerkAutomaticPresenter)? {
    guard let presenterType = NSClassFromString(presenterClassName) as? NSObject.Type else {
      return nil
    }
    return presenterType.init() as? any ClerkAutomaticPresenter
  }
}

extension Clerk {
  func startAutomaticPresenter() {
    guard options.updateRequiredViewEnabled,
          !EnvironmentDetection.isRunningInTests,
          !EnvironmentDetection.isRunningInPreviews
    else {
      return
    }

    if automaticPresenter == nil {
      automaticPresenter = ClerkAutomaticPresenterLoader.load()
    }
    automaticPresenter?.start(clerk: self)
  }

  func stopAutomaticPresenter() {
    automaticPresenter?.stop()
  }
}
