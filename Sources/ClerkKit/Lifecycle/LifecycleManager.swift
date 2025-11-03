//
//  LifecycleManager.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// Protocol defining callbacks for app lifecycle events.
///
/// Implementations of this protocol can respond to foreground and background transitions
/// to perform necessary actions like refreshing data or cleaning up resources.
protocol LifecycleEventHandling: Sendable {
  /// Called when the app is about to enter the foreground.
  ///
  /// Use this to resume background tasks, refresh data, or restart polling.
  @MainActor func onWillEnterForeground() async
  
  /// Called when the app has entered the background.
  ///
  /// Use this to pause background tasks, flush telemetry, or save state.
  @MainActor func onDidEnterBackground() async
}

/// Manages app lifecycle notifications and coordinates foreground/background transitions.
///
/// This class handles the registration and cleanup of notification observers for app lifecycle events.
/// It ensures proper task cancellation and resource cleanup when the app transitions between states.
@MainActor
final class LifecycleManager {
  
  /// Task that observes foreground notifications.
  nonisolated(unsafe) private var willEnterForegroundTask: Task<Void, Error>?
  
  /// Task that observes background notifications.
  nonisolated(unsafe) private var didEnterBackgroundTask: Task<Void, Error>?
  
  /// The handler that responds to lifecycle events.
  private let handler: any LifecycleEventHandling
  
  /// Creates a new lifecycle manager with the provided event handler.
  ///
  /// - Parameter handler: The object that will handle lifecycle events.
  init(handler: any LifecycleEventHandling) {
    self.handler = handler
  }
  
  /// Starts observing app lifecycle notifications.
  ///
  /// This method sets up notification observers for foreground and background transitions.
  /// If observers are already active, existing tasks are cancelled before creating new ones.
  func startObserving() {
    #if !os(watchOS) && !os(macOS)
    
    // Cancel existing tasks if they exist (switching instances)
    willEnterForegroundTask?.cancel()
    didEnterBackgroundTask?.cancel()
    
    willEnterForegroundTask = Task {
      for await _ in NotificationCenter.default.notifications(
        named: UIApplication.willEnterForegroundNotification
      ).map({ _ in () }) {
        await handler.onWillEnterForeground()
      }
    }
    
    didEnterBackgroundTask = Task {
      for await _ in NotificationCenter.default.notifications(
        named: UIApplication.didEnterBackgroundNotification
      ).map({ _ in () }) {
        await handler.onDidEnterBackground()
      }
    }
    
    #endif
  }
  
  /// Stops observing app lifecycle notifications and cancels all active tasks.
  ///
  /// This method should be called when the lifecycle manager is no longer needed
  /// to ensure proper cleanup of resources.
  nonisolated func stopObserving() {
    willEnterForegroundTask?.cancel()
    willEnterForegroundTask = nil
    
    didEnterBackgroundTask?.cancel()
    didEnterBackgroundTask = nil
  }
  
  /// Cancels all active tasks and stops observing.
  ///
  /// This is called automatically when the manager is deallocated.
  deinit {
    stopObserving()
  }
}

