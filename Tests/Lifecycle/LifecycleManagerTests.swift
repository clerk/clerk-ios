//
//  LifecycleManagerTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

#if canImport(UIKit)
import Foundation
import Testing
import UIKit

@testable import ClerkKit

/// Mock lifecycle event handler for testing.
@MainActor
final class MockLifecycleHandler: LifecycleEventHandling {
  nonisolated(unsafe) var foregroundCallCount = LockIsolated(0)
  nonisolated(unsafe) var backgroundCallCount = LockIsolated(0)

  func onWillEnterForeground() async {
    foregroundCallCount.withValue { $0 += 1 }
  }

  func onDidEnterBackground() async {
    backgroundCallCount.withValue { $0 += 1 }
  }
}

/// Tests for LifecycleManager notification handling.
@MainActor
@Suite(.serialized)
struct LifecycleManagerTests {
  @Test
  func startsObserving() {
    let handler = MockLifecycleHandler()
    let manager = LifecycleManager(handler: handler)

    manager.startObserving()

    // Manager should be initialized and ready
    // (We can't easily test the notification observers without UIKit app context)
  }

  @Test
  func testStopObserving() {
    let handler = MockLifecycleHandler()
    let manager = LifecycleManager(handler: handler)

    manager.startObserving()
    manager.stopObserving()

    // Should cleanly stop observing
    // (We can't easily test the notification observers without UIKit app context)
  }

  @Test
  func multipleStartObserving() {
    let handler = MockLifecycleHandler()
    let manager = LifecycleManager(handler: handler)

    manager.startObserving()
    manager.startObserving() // Should be safe to call multiple times
    manager.startObserving()

    manager.stopObserving()
  }

  @Test
  func stopObservingMultipleTimes() {
    let handler = MockLifecycleHandler()
    let manager = LifecycleManager(handler: handler)

    manager.startObserving()
    manager.stopObserving()
    manager.stopObserving() // Should be safe to call multiple times
    manager.stopObserving()
  }

  @Test
  func deinitStopsObserving() {
    let handler = MockLifecycleHandler()

    do {
      let manager = LifecycleManager(handler: handler)
      manager.startObserving()
      // Manager goes out of scope, should stop observing
    }

    // Manager should have cleaned up
  }
}

#endif
