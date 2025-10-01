import Foundation

/// Responsible for logging pending session messaging without bloating the Clerk entry point.
final class PendingSessionLogger {
  func logChange(previousClient: Client?, currentClient: Client) {
    guard shouldLog(previousClient: previousClient, currentClient: currentClient) else {
      return
    }

    let tasksDescription: String
    if let sessionId = currentClient.lastActiveSessionId,
       let session = currentClient.sessions.first(where: { $0.id == sessionId }),
       let tasks = session.tasks,
       !tasks.isEmpty {
      let taskKeys = tasks.map(\.key).joined(separator: ", ")
      tasksDescription = " Remaining session tasks: [\(taskKeys)]."
    } else {
      tasksDescription = ""
    }

    let message = "Your session is currently pending. Complete the remaining session tasks to activate it.\(tasksDescription)"
    Logger.log(level: .info, scope: .session, message: message)
  }
}

private extension PendingSessionLogger {
  func shouldLog(previousClient: Client?, currentClient: Client) -> Bool {
    guard let sessionId = currentClient.lastActiveSessionId,
          let session = currentClient.sessions.first(where: { $0.id == sessionId }) else {
      return false
    }

    guard session.status == .pending else {
      return false
    }

    guard let previousClient,
          let previousId = previousClient.lastActiveSessionId,
          let previousSession = previousClient.sessions.first(where: { $0.id == previousId }) else {
      return true
    }

    if previousSession.id != session.id { return true }
    if previousSession.status != session.status { return true }
    if (previousSession.tasks ?? []) != (session.tasks ?? []) { return true }

    return false
  }
}
