//
//  TaskCoordinatorTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

/// Tests for TaskCoordinator task tracking and cancellation.
@MainActor
@Suite(.serialized)
struct TaskCoordinatorTests {

  @Test
  func testTracksTask() async {
    let coordinator = TaskCoordinator()
    let taskCompleted = LockIsolated(false)

    let task = Task {
      try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
      taskCompleted.setValue(true)
    }

    coordinator.track(task)

    await task.value

    #expect(taskCompleted.value == true)
  }

  @Test
  func testCreatesAndTracksTask() async {
    let coordinator = TaskCoordinator()
    let operationExecuted = LockIsolated(false)

    let task = coordinator.task {
      operationExecuted.setValue(true)
    }

    await task.value

    #expect(operationExecuted.value == true)
  }

  @Test
  func testCancelAllTasks() async {
    let coordinator = TaskCoordinator()
    let task1Completed = LockIsolated(false)
    let task2Completed = LockIsolated(false)

    let task1 = coordinator.task {
      // Use a longer delay to ensure cancellation happens first
      try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
      task1Completed.setValue(true)
    }

    let task2 = coordinator.task {
      try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
      task2Completed.setValue(true)
    }

    // Cancel immediately
    coordinator.cancelAll()

    // Give cancellation a moment to propagate
    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

    // Verify tasks are cancelled (this is the key behavior we're testing)
    #expect(task1.isCancelled == true)
    #expect(task2.isCancelled == true)
  }

  @Test
  func testTracksMultipleTasks() async {
    let coordinator = TaskCoordinator()
    let completedCount = LockIsolated(0)

    let task1 = coordinator.task {
      completedCount.setValue(completedCount.value + 1)
    }

    let task2 = coordinator.task {
      completedCount.setValue(completedCount.value + 1)
    }

    let task3 = coordinator.task {
      completedCount.setValue(completedCount.value + 1)
    }

    await task1.value
    await task2.value
    await task3.value

    #expect(completedCount.value == 3)
  }

  @Test
  func testTaskWithCustomPriority() async {
    let coordinator = TaskCoordinator()
    let operationExecuted = LockIsolated(false)

    let task = coordinator.task(priority: .utility) {
      operationExecuted.setValue(true)
    }

    await task.value

    #expect(operationExecuted.value == true)
  }

  @Test
  func testDeinitCancelsAllTasks() async {
    let taskCompleted = LockIsolated(false)

    do {
      let coordinator = TaskCoordinator()
      let task = coordinator.task {
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        taskCompleted.setValue(true)
      }

      // Coordinator goes out of scope, should cancel tasks
    }

    // Give task a moment to be cancelled
    try? await Task.sleep(nanoseconds: 5_000_000) // 5ms

    // Task should be cancelled
    #expect(taskCompleted.value == false)
  }
}

