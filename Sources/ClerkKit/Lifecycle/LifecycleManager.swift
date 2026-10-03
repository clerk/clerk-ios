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
@MainActor
final class LifecycleManager {
  private var willEnterForegroundTask: Task<Void, Never>?

  private var didEnterBackgroundTask: Task<Void, Never>?

  private let handler: any LifecycleEventHandling

  private let notificationCenter: NotificationCenter

  private let tasks: TaskCoordinator

  init(
    handler: any LifecycleEventHandling,
    notificationCenter: NotificationCenter = .default,
    tasks: TaskCoordinator = TaskCoordinator()
  ) {
    self.handler = handler
    self.notificationCenter = notificationCenter
    self.tasks = tasks
  }

  func startObserving() {
    willEnterForegroundTask?.cancel()
    didEnterBackgroundTask?.cancel()

    let willEnterForeground = notificationCenter.notifications(named: Self.willEnterForegroundNotification)
    let didEnterBackground = notificationCenter.notifications(named: Self.didEnterBackgroundNotification)

    let foregroundTask = Task { [handler] in
      for await _ in willEnterForeground.map({ _ in () }) {
        guard !Task.isCancelled else { break }
        await handler.onWillEnterForeground()
      }
    }
    willEnterForegroundTask = foregroundTask
    tasks.track(foregroundTask)

    let backgroundTask = Task { [handler] in
      for await _ in didEnterBackground.map({ _ in () }) {
        guard !Task.isCancelled else { break }
        await handler.onDidEnterBackground()
      }
    }
    didEnterBackgroundTask = backgroundTask
    tasks.track(backgroundTask)
  }

  func stopObserving() {
    willEnterForegroundTask?.cancel()
    willEnterForegroundTask = nil

    didEnterBackgroundTask?.cancel()
    didEnterBackgroundTask = nil
  }

  deinit {
    willEnterForegroundTask?.cancel()
    didEnterBackgroundTask?.cancel()
  }
}

extension LifecycleManager {
  static var willEnterForegroundNotification: Notification.Name {
    #if os(macOS)
    NSApplication.didBecomeActiveNotification
    #elseif os(watchOS)
    WKApplication.willEnterForegroundNotification
    #else
    UIApplication.willEnterForegroundNotification
    #endif
  }

  static var didEnterBackgroundNotification: Notification.Name {
    #if os(macOS)
    NSApplication.didResignActiveNotification
    #elseif os(watchOS)
    WKApplication.didEnterBackgroundNotification
    #else
    UIApplication.didEnterBackgroundNotification
    #endif
  }
}
