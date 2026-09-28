//
//  LifecycleManagerTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

#if canImport(UIKit)
@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing
import UIKit

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
  }

  @Test
  func testStopObserving() {
    let handler = MockLifecycleHandler()
    let manager = LifecycleManager(handler: handler)

    manager.startObserving()
    manager.stopObserving()
  }

  @Test
  func multipleStartObserving() {
    let handler = MockLifecycleHandler()
    let manager = LifecycleManager(handler: handler)

    manager.startObserving()
    manager.startObserving()
    manager.startObserving()

    manager.stopObserving()
  }

  @Test
  func stopObservingMultipleTimes() {
    let handler = MockLifecycleHandler()
    let manager = LifecycleManager(handler: handler)

    manager.startObserving()
    manager.stopObserving()
    manager.stopObserving()
    manager.stopObserving()
  }

  @Test
  func deinitStopsObserving() {
    let handler = MockLifecycleHandler()

    do {
      let manager = LifecycleManager(handler: handler)
      manager.startObserving()
    }
  }
}

#endif
