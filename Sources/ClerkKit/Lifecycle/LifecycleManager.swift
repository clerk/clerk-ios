//
//  LifecycleManager.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

#if os(watchOS)
import WatchKit
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

protocol LifecycleEventHandling: Sendable {
  @MainActor func onWillEnterForeground() async

  @MainActor func onDidEnterBackground() async
}

/// Manages app lifecycle notifications and coordinates foreground/background transitions.
///
/// This class handles the registration and cleanup of notification observers for app lifecycle events.
/// Call `stopObserving()` before releasing the manager to ensure proper cleanup.
@MainActor
final class LifecycleManager {
  private var willEnterForegroundTask: Task<Void, Error>?

  private var didEnterBackgroundTask: Task<Void, Error>?

  private let handler: any LifecycleEventHandling

  init(handler: any LifecycleEventHandling) {
    self.handler = handler
  }

  func startObserving() {
    willEnterForegroundTask?.cancel()
    didEnterBackgroundTask?.cancel()

    willEnterForegroundTask = Task {
      for await _ in NotificationCenter.default.notifications(
        named: Self.willEnterForegroundNotification
      ).map({ _ in () }) {
        await handler.onWillEnterForeground()
      }
    }

    didEnterBackgroundTask = Task {
      for await _ in NotificationCenter.default.notifications(
        named: Self.didEnterBackgroundNotification
      ).map({ _ in () }) {
        await handler.onDidEnterBackground()
      }
    }
  }

  func stopObserving() {
    willEnterForegroundTask?.cancel()
    willEnterForegroundTask = nil

    didEnterBackgroundTask?.cancel()
    didEnterBackgroundTask = nil
  }
}

extension LifecycleManager {
  private static var willEnterForegroundNotification: Notification.Name {
    #if os(macOS)
    NSApplication.didBecomeActiveNotification
    #elseif os(watchOS)
    WKApplication.willEnterForegroundNotification
    #else
    UIApplication.willEnterForegroundNotification
    #endif
  }

  private static var didEnterBackgroundNotification: Notification.Name {
    #if os(macOS)
    NSApplication.didResignActiveNotification
    #elseif os(watchOS)
    WKApplication.didEnterBackgroundNotification
    #else
    UIApplication.didEnterBackgroundNotification
    #endif
  }
}
