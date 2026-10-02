//
//  TaskCoordinator.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Manages and coordinates tasks for cleanup and cancellation.
@MainActor
final class TaskCoordinator {
  private struct TrackedTask {
    let cancel: @Sendable () -> Void
    let wait: @Sendable () async -> Void
  }

  private var tasks: [UUID: TrackedTask] = [:]

  init() {}

  func track(_ task: Task<some Sendable, some Error>) {
    let id = UUID()
    tasks[id] = TrackedTask(
      cancel: { task.cancel() },
      wait: { _ = await task.result }
    )

    Task { [weak self] in
      _ = await task.result
      self?.tasks[id] = nil
    }
  }

  @discardableResult
  func task(
    priority: TaskPriority = .userInitiated,
    operation: @escaping @Sendable () async -> Void
  ) -> Task<Void, Never> {
    let task = Task(priority: priority) {
      await operation()
    }
    track(task)
    return task
  }

  func cancelAll() {
    for task in tasks.values {
      task.cancel()
    }
    tasks.removeAll()
  }

  func cancelAllAndWait() async {
    let trackedTasks = Array(tasks.values)
    for task in trackedTasks {
      task.cancel()
    }
    tasks.removeAll()

    for task in trackedTasks {
      await task.wait()
    }
  }

  deinit {
    for task in tasks.values {
      task.cancel()
    }
  }
}
