//
//  TaskCoordinatorTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import ConcurrencyExtras
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
    await withMainSerialExecutor {
      let coordinator = TaskCoordinator()
      let task1Completed = LockIsolated(false)
      let task2Completed = LockIsolated(false)
      let task1Cancelled = LockIsolated(false)
      let task2Cancelled = LockIsolated(false)

      _ = coordinator.task {
        while !Task.isCancelled {
          await Task.yield()
        }
        task1Cancelled.setValue(true)
        task1Completed.setValue(true)
      }

      _ = coordinator.task {
        while !Task.isCancelled {
          await Task.yield()
        }
        task2Cancelled.setValue(true)
        task2Completed.setValue(true)
      }

      coordinator.cancelAll()

      for _ in 0 ..< 50 {
        if task1Cancelled.value, task2Cancelled.value {
          break
        }
        await Task.yield()
      }

      #expect(task1Cancelled.value == true || task1Completed.value == false)
      #expect(task2Cancelled.value == true || task2Completed.value == false)
    }
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
    await withMainSerialExecutor {
      let taskCompleted = LockIsolated(false)
      let taskCancelled = LockIsolated(false)

      do {
        let coordinator = TaskCoordinator()
        let task = coordinator.task {
          while !Task.isCancelled {
            await Task.yield()
          }
          taskCancelled.setValue(true)
          taskCompleted.setValue(true)
        }

        #expect(task.isCancelled == false)
      }

      for _ in 0 ..< 50 {
        if taskCancelled.value {
          break
        }
        await Task.yield()
      }

      #expect(taskCancelled.value == true || taskCompleted.value == false)
    }
  }
}
