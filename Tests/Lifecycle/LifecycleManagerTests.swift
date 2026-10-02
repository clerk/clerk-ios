//
//  LifecycleManagerTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

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

@MainActor
@Suite(.serialized)
struct LifecycleManagerTests {
  @Test
  func startsObserving() async throws {
    let center = NotificationCenter()
    let handler = MockLifecycleHandler()
    let manager = LifecycleManager(handler: handler, notificationCenter: center)

    manager.startObserving()

    center.post(name: LifecycleManager.willEnterForegroundNotification, object: nil)
    try await waitUntil { handler.foregroundCallCount.value == 1 }
    #expect(handler.backgroundCallCount.value == 0)

    center.post(name: LifecycleManager.didEnterBackgroundNotification, object: nil)
    try await waitUntil { handler.backgroundCallCount.value == 1 }
    #expect(handler.foregroundCallCount.value == 1)

    manager.stopObserving()
  }

  @Test
  func testStopObserving() async throws {
    let center = NotificationCenter()
    let handler = MockLifecycleHandler()
    let manager = LifecycleManager(handler: handler, notificationCenter: center)

    manager.startObserving()
    center.post(name: LifecycleManager.willEnterForegroundNotification, object: nil)
    try await waitUntil { handler.foregroundCallCount.value == 1 }

    manager.stopObserving()

    postLifecycleNotifications(center)
    await settle()

    #expect(handler.foregroundCallCount.value == 1)
    #expect(handler.backgroundCallCount.value == 0)
  }

  @Test
  func multipleStartObserving() async throws {
    let center = NotificationCenter()
    let handler = MockLifecycleHandler()
    let manager = LifecycleManager(handler: handler, notificationCenter: center)

    manager.startObserving()
    manager.startObserving()
    manager.startObserving()

    postLifecycleNotifications(center)
    try await waitUntil {
      handler.foregroundCallCount.value >= 1 && handler.backgroundCallCount.value >= 1
    }
    await settle()

    #expect(handler.foregroundCallCount.value == 1)
    #expect(handler.backgroundCallCount.value == 1)

    manager.stopObserving()
  }

  @Test
  func stopObservingMultipleTimes() async throws {
    let center = NotificationCenter()
    let handler = MockLifecycleHandler()
    let manager = LifecycleManager(handler: handler, notificationCenter: center)

    manager.startObserving()
    manager.stopObserving()
    manager.stopObserving()
    manager.stopObserving()

    postLifecycleNotifications(center)
    await settle()
    #expect(handler.foregroundCallCount.value == 0)
    #expect(handler.backgroundCallCount.value == 0)

    manager.startObserving()
    postLifecycleNotifications(center)
    try await waitUntil {
      handler.foregroundCallCount.value == 1 && handler.backgroundCallCount.value == 1
    }

    manager.stopObserving()
  }

  @Test
  func releasedManagerStopsObserving() async {
    let center = NotificationCenter()
    let handler = MockLifecycleHandler()
    weak var released: LifecycleManager?

    do {
      let manager = LifecycleManager(handler: handler, notificationCenter: center)
      released = manager
      manager.startObserving()
    }

    #expect(released == nil)

    postLifecycleNotifications(center)
    await settle()
    #expect(handler.foregroundCallCount.value == 0)
    #expect(handler.backgroundCallCount.value == 0)
  }

  private func postLifecycleNotifications(_ center: NotificationCenter) {
    center.post(name: LifecycleManager.willEnterForegroundNotification, object: nil)
    center.post(name: LifecycleManager.didEnterBackgroundNotification, object: nil)
  }

  /// Lets any pending observer work run so a delivery that shouldn't happen has the chance to.
  private func settle() async {
    for _ in 0 ..< 20 {
      await Task.yield()
    }
  }

  private func waitUntil(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + .seconds(1)
    while ContinuousClock.now < deadline {
      if condition() { return }
      await Task.yield()
    }
    throw ClerkClientError(message: "Timed out waiting for lifecycle handler.")
  }
}
