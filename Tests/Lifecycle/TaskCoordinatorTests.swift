//
//  TaskCoordinatorTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct TaskCoordinatorTests {
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
  func cancelAllCancelsEveryTrackedTask() async {
    await withMainSerialExecutor {
      let coordinator = TaskCoordinator()
      let task1Cancelled = LockIsolated(false)
      let task2Cancelled = LockIsolated(false)

      _ = coordinator.task {
        while !Task.isCancelled {
          await Task.yield()
        }
        task1Cancelled.setValue(true)
      }

      _ = coordinator.task {
        while !Task.isCancelled {
          await Task.yield()
        }
        task2Cancelled.setValue(true)
      }

      coordinator.cancelAll()

      for _ in 0 ..< 50 {
        if task1Cancelled.value, task2Cancelled.value {
          break
        }
        await Task.yield()
      }

      #expect(task1Cancelled.value)
      #expect(task2Cancelled.value)
    }
  }

  @Test
  func deinitCancelsAllTasks() async {
    await withMainSerialExecutor {
      let taskCancelled = LockIsolated(false)
      weak var released: TaskCoordinator?

      do {
        let coordinator = TaskCoordinator()
        released = coordinator
        let task = coordinator.task {
          while !Task.isCancelled {
            await Task.yield()
          }
          taskCancelled.setValue(true)
        }

        #expect(task.isCancelled == false)
      }

      for _ in 0 ..< 50 {
        if taskCancelled.value {
          break
        }
        await Task.yield()
      }

      #expect(released == nil)
      #expect(taskCancelled.value)
    }
  }
}
