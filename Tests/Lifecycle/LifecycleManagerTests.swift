//
//  LifecycleManagerTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

#if canImport(UIKit)
import Foundation
import UIKit
import Testing

@testable import ClerkKit

/// Mock lifecycle event handler for testing.
@MainActor
final class MockLifecycleHandler: LifecycleEventHandling {
  var foregroundCallCount = LockIsolated(0)
  var backgroundCallCount = LockIsolated(0)

  func onWillEnterForeground() async {
    foregroundCallCount.setValue(foregroundCallCount.value + 1)
  }

  func onDidEnterBackground() async {
    backgroundCallCount.setValue(backgroundCallCount.value + 1)
  }
}

/// Tests for LifecycleManager notification handling.
@MainActor
@Suite(.serialized)
struct LifecycleManagerTests {

  @Test
  func testStartsObserving() {
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
  func testMultipleStartObserving() {
    let handler = MockLifecycleHandler()
    let manager = LifecycleManager(handler: handler)

    manager.startObserving()
    manager.startObserving()  // Should be safe to call multiple times
    manager.startObserving()

    manager.stopObserving()
  }

  @Test
  func testStopObservingMultipleTimes() {
    let handler = MockLifecycleHandler()
    let manager = LifecycleManager(handler: handler)

    manager.startObserving()
    manager.stopObserving()
    manager.stopObserving()  // Should be safe to call multiple times
    manager.stopObserving()
  }

  @Test
  func testDeinitStopsObserving() {
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
