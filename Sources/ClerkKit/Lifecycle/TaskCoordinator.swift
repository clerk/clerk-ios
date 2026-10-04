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
  private var tasks: Set<Task<Void, Never>> = []

  init() {}

  func track(_ task: Task<Void, Never>) {
    tasks.insert(task)

    Task { [weak self] in
      await task.value
      self?.tasks.remove(task)
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
    for task in tasks {
      task.cancel()
    }
    tasks.removeAll()
  }

  func cancelAllAndWait() async {
    let trackedTasks = tasks
    for task in trackedTasks {
      task.cancel()
    }
    tasks.removeAll()

    for task in trackedTasks {
      await task.value
    }
  }

  deinit {
    for task in tasks {
      task.cancel()
    }
  }
}
