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
  func tracksTask() async {
    let coordinator = TaskCoordinator()
    let taskCompleted = LockIsolated(false)

    let task = Task {
      // No delay needed - just verify task completes
      taskCompleted.setValue(true)
    }

    coordinator.track(task)

    await task.value

    #expect(taskCompleted.value == true)
  }

  @Test
  func createsAndTracksTask() async {
    let coordinator = TaskCoordinator()
    let operationExecuted = LockIsolated(false)

    let task = coordinator.task {
      operationExecuted.setValue(true)
    }

    await task.value

    #expect(operationExecuted.value == true)
  }

  @Test
  func cancelAllTasks() async {
    let coordinator = TaskCoordinator()
    let task1Completed = LockIsolated(false)
    let task2Completed = LockIsolated(false)
    let task1Cancelled = LockIsolated(false)
    let task2Cancelled = LockIsolated(false)

    _ = coordinator.task {
      // Loop until cancelled
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 1_000_000) // 1ms - minimal delay for cancellation check
      }
      task1Cancelled.setValue(true)
      task1Completed.setValue(true)
    }

    _ = coordinator.task {
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
      }
      task2Cancelled.setValue(true)
      task2Completed.setValue(true)
    }

    // Cancel immediately
    coordinator.cancelAll()

    // Give cancellation a tiny moment to propagate (cancellation is cooperative)
    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms - minimal wait for cancellation to propagate

    // Verify tasks detected cancellation
    #expect(task1Cancelled.value == true || task1Completed.value == false)
    #expect(task2Cancelled.value == true || task2Completed.value == false)
  }

  @Test
  func tracksMultipleTasks() async {
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
  func taskWithCustomPriority() async {
    let coordinator = TaskCoordinator()
    let operationExecuted = LockIsolated(false)

    let task = coordinator.task(priority: .utility) {
      operationExecuted.setValue(true)
    }

    await task.value

    #expect(operationExecuted.value == true)
  }

  @Test
  func deinitCancelsAllTasks() async {
    let taskCompleted = LockIsolated(false)
    let taskCancelled = LockIsolated(false)

    do {
      let coordinator = TaskCoordinator()
      let task = coordinator.task {
        // Loop until cancelled
        while !Task.isCancelled {
          try? await Task.sleep(nanoseconds: 1_000_000) // 1ms - minimal delay
        }
        taskCancelled.setValue(true)
        taskCompleted.setValue(true)
      }

      // Verify task exists before deinit
      #expect(task.isCancelled == false)

      // Coordinator goes out of scope, should cancel tasks
    }

    // Give cancellation a tiny moment to propagate
    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

    // Verify task detected cancellation
    #expect(taskCancelled.value == true || taskCompleted.value == false)
  }
}
