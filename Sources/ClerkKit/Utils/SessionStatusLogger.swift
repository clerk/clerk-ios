//
//  SessionStatusLogger.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

@MainActor
final class SessionStatusLogger {
  func logPendingSessionStatusIfNeeded(previousClient: Client?, currentClient: Client) {
    guard shouldLogPendingSessionStatus(previousClient: previousClient, currentClient: currentClient) else {
      return
    }

    logPendingSessionStatus(currentClient: currentClient)
  }

  private func logPendingSessionStatus(currentClient: Client) {
    let tasksDescription: String
    if let session = currentClient.currentSession,
       let tasks = session.tasks,
       !tasks.isEmpty
    {
      let taskList = tasks.map(\.rawValue).joined(separator: ", ")
      tasksDescription = " Remaining session tasks: [\(taskList)]."
    } else {
      tasksDescription = ""
    }

    let message = "Your session is currently pending. Complete the remaining session tasks to activate it.\(tasksDescription)"
    ClerkLogger.info(message, force: true)
  }

  func shouldLogPendingSessionStatus(previousClient: Client?, currentClient: Client) -> Bool {
    guard let session = currentClient.currentSession else {
      return false
    }

    guard session.status == .pending else {
      return false
    }

    guard let previousClient,
          let previousSession = previousClient.currentSession
    else {
      return true
    }

    if previousSession.id != session.id {
      return true
    }

    if previousSession.status != session.status {
      return true
    }

    if (previousSession.tasks ?? []) != (session.tasks ?? []) {
      return true
    }

    return false
  }
}
