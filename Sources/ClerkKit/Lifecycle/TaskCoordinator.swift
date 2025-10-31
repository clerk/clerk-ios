//
//  TaskCoordinator.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Manages and coordinates tasks for cleanup and cancellation.
///
/// This class provides a centralized way to track and cancel tasks,
/// ensuring proper cleanup when the coordinator is deallocated.
@MainActor
final class TaskCoordinator {
    
    /// Storage for tracked tasks.
    nonisolated(unsafe) private var tasks: Set<Task<Void, Never>> = []
    
    /// Creates a new task coordinator.
    init() {}
    
    /// Adds a task to be tracked by this coordinator.
    ///
    /// - Parameter task: The task to track.
    func track(_ task: Task<Void, Never>) {
        tasks.insert(task)
        
        // Remove task when it completes
        Task {
            await task.value
            tasks.remove(task)
        }
    }
    
    /// Creates and tracks a new task.
    ///
    /// - Parameter priority: The priority of the task. Defaults to `.userInitiated`.
    /// - Parameter operation: The async operation to perform.
    /// - Returns: The created task.
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
    
    /// Cancels all tracked tasks.
    nonisolated func cancelAll() {
        for task in tasks {
            task.cancel()
        }
        tasks.removeAll()
    }
    
    /// Cancels all tracked tasks and cleans up resources.
    ///
    /// This is called automatically when the coordinator is deallocated.
    nonisolated deinit {
        cancelAll()
    }
}

