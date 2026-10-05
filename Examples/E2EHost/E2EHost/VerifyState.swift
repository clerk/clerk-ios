//
//  VerifyState.swift
//  E2EHost
//

import ClerkKit
import Foundation
import OSLog
import SwiftUI

struct VerifyState: Encodable, Equatable {
  enum Ticket: String, Encodable {
    case none
    case pending
    case succeeded
    case failed
  }

  struct Failure: Encodable, Equatable {
    let code: String
    let message: String

    init(code: String, message: String) {
      self.code = code
      self.message = message
    }

    init(_ error: Error, fallbackCode: String) {
      if let apiError = error as? ClerkAPIError {
        code = apiError.code
        message = apiError.longMessage ?? apiError.message ?? apiError.localizedDescription
      } else {
        code = fallbackCode
        message = error.localizedDescription
      }
    }
  }

  let v = 1
  let runId: String?
  let launchId: String?
  let screen: String
  let environmentLoaded: Bool
  let signedIn: Bool
  let userId: String?
  let sessionId: String?
  let sessionStatus: String?
  let pendingTasks: [String]
  let orgId: String?
  let signInStatus: String?
  let signUpStatus: String?
  let ticket: Ticket
  let lastError: Failure?

  init(
    configuration: E2EConfiguration,
    screen: String,
    clerk: Clerk?,
    ticket: Ticket,
    lastError: Failure?
  ) {
    let session = clerk?.session

    runId = configuration.runId
    launchId = configuration.launchId
    self.screen = screen
    environmentLoaded = clerk?.environment != nil
    signedIn = clerk?.user != nil
    userId = clerk?.user?.id
    sessionId = session?.id
    sessionStatus = switch session?.status {
    case .active?: "active"
    case .pending?: "pending"
    default: nil
    }
    pendingTasks = session?.tasks?.map(\.rawValue) ?? []
    orgId = clerk?.organization?.id
    signInStatus = clerk?.client?.signIn?.status.rawValue
    signUpStatus = clerk?.client?.signUp?.status.rawValue
    self.ticket = ticket
    self.lastError = lastError
  }

  var line: String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let json = (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    return "verify \(json)"
  }
}

struct VerifyStateFooter: View {
  private static let logger = Logger(subsystem: "com.clerk.verify", category: "state")

  let state: VerifyState

  var body: some View {
    Text(state.line)
      .font(.caption2.monospaced())
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal)
      .accessibilityIdentifier(E2EIdentifiers.Verify.state)
      .onChange(of: state, initial: true) {
        Self.logger.log("\(state.line, privacy: .public)")
      }
  }
}
