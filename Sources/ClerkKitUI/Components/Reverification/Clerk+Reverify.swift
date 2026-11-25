//
//  Clerk+Reverify.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

extension Clerk {
  /// Asks the user to verify their identity again, unless they already did within `reverification`.
  ///
  /// When ``Clerk/has(reverification:)`` is `false`, it presents Clerk's reverification sheet
  /// over whatever your app shows, including other sheets, and returns once the user verifies.
  /// Your app doesn't need to set anything up for the sheet.
  ///
  /// ```swift
  /// try await clerk.reverify(.strict)
  /// try await deleteAccount()
  /// ```
  ///
  /// - Throws: ``ReverificationCancelledError`` when the user closes the sheet, or an error when
  ///   `reverification` is a custom requirement whose level or age Clerk doesn't support.
  public func reverify(_ reverification: ReverificationConfig) async throws {
    try await Reverifier(clerk: self)(reverification)
  }

  /// Runs `operation`, and when it throws an error that asks for reverification, asks the user
  /// to verify and runs `operation` once more.
  ///
  /// An error asks for reverification when ``ReverificationRequiredError/init(_:)`` recognizes
  /// it: a ``ReverificationRequiredError`` your code throws, the error your backend returns
  /// through Clerk's backend SDKs, or Clerk's `session_reverification_required` API error. The
  /// sheet is presented over whatever your app shows, including other sheets.
  ///
  /// ```swift
  /// do {
  ///   try await clerk.reverify {
  ///     try await api.transferFunds()
  ///   }
  /// } catch is ReverificationCancelledError {
  ///   // The user closed the sheet.
  /// }
  /// ```
  ///
  /// - Throws: ``ReverificationCancelledError`` when the user closes the sheet, or the error
  ///   `operation` throws.
  @discardableResult
  public func reverify<T>(_ operation: @MainActor () async throws -> T) async throws -> T {
    try await Reverifier(clerk: self)(operation)
  }
}

/// The error ``Clerk/reverify(_:)`` throws when the user closes the reverification sheet before verifying.
public struct ReverificationCancelledError: Error, Equatable, Sendable {
  public init() {}
}

@MainActor
struct Reverifier {
  private let isSatisfied: @MainActor (ReverificationConfig) -> Bool
  private let present: @MainActor (SessionVerification.Level) async throws -> Void
  private let currentSessionId: @MainActor () -> String?

  init(
    isSatisfied: @escaping @MainActor (ReverificationConfig) -> Bool,
    currentSessionId: @escaping @MainActor () -> String? = { nil },
    present: @escaping @MainActor (SessionVerification.Level) async throws -> Void
  ) {
    self.isSatisfied = isSatisfied
    self.currentSessionId = currentSessionId
    self.present = present
  }

  init(clerk: Clerk, presenter: ReverificationPresenter = .shared) {
    self.init(
      isSatisfied: { clerk.has(reverification: $0) },
      currentSessionId: { clerk.session?.id },
      present: { try await presenter.present(level: $0, clerk: clerk) }
    )
  }

  func callAsFunction(_ reverification: ReverificationConfig) async throws {
    guard !isSatisfied(reverification) else { return }
    guard let requirement = reverification.requirement else {
      throw ReverificationUnsupportedRequirementError()
    }
    try await present(requirement.level)
    try Task.checkCancellation()
  }

  func callAsFunction<T>(_ operation: @MainActor () async throws -> T) async throws -> T {
    let sessionId = currentSessionId()
    do {
      return try await operation()
    } catch {
      guard let required = ReverificationRequiredError(error) else { throw error }
      try ensureSession(is: sessionId)
      try await present(required.reverification?.requirement?.level ?? .secondFactor)
      try Task.checkCancellation()
      try ensureSession(is: sessionId)
      return try await operation()
    }
  }

  private func ensureSession(is sessionId: String?) throws {
    guard currentSessionId() == sessionId else {
      throw ReverificationCancelledError()
    }
  }
}

@MainActor
protocol ReverificationSheetDisplay {
  func show(
    _ request: ReverificationRequest,
    clerk: Clerk,
    onDismiss: @escaping @MainActor () -> Void
  ) async -> Bool
}

@MainActor
final class ReverificationPresenter {
  static let shared = ReverificationPresenter(display: PlatformReverificationSheetDisplay())

  private let display: any ReverificationSheetDisplay
  private var active: ReverificationRequest?

  init(display: any ReverificationSheetDisplay) {
    self.display = display
  }

  func present(level: SessionVerification.Level, clerk: Clerk) async throws {
    while let active, active.level != level {
      try? await active.wait()
    }
    try Task.checkCancellation()

    if let active {
      try await active.wait()
      return
    }

    let request = ReverificationRequest(level: level)
    active = request
    let isShown = await display.show(request, clerk: clerk) { [weak self] in
      self?.didDismiss(request)
    }
    guard isShown else {
      let error = ReverificationNotPresentedError()
      ClerkLogger.error("Failed to present reverification", error: error)
      if active === request {
        active = nil
      }
      request.finish(throwing: error)
      throw error
    }

    try await request.wait()
  }

  private func didDismiss(_ request: ReverificationRequest) {
    if active === request {
      active = nil
    }
    request.finish()
  }
}

@MainActor
final class ReverificationRequest {
  let level: SessionVerification.Level
  private var continuations: [CheckedContinuation<Void, Error>] = []
  private var result: Result<Void, Error>?
  private(set) var didComplete = false

  init(level: SessionVerification.Level) {
    self.level = level
  }

  func wait() async throws {
    if let result {
      return try result.get()
    }
    try await withCheckedThrowingContinuation { continuations.append($0) }
  }

  func markComplete() {
    didComplete = true
  }

  func finish() {
    resume(with: didComplete ? .success(()) : .failure(ReverificationCancelledError()))
  }

  func finish(throwing error: Error) {
    resume(with: .failure(error))
  }

  private func resume(with result: Result<Void, Error>) {
    guard self.result == nil else { return }
    self.result = result
    let waiting = continuations
    continuations = []
    waiting.forEach { $0.resume(with: result) }
  }
}

struct ReverificationUnsupportedRequirementError: LocalizedError {
  var errorDescription: String? {
    "Clerk can't reverify with this requirement because its level or age isn't one Clerk supports."
  }
}

@MainActor
final class OneTimeAction<Value> {
  private var action: ((Value) -> Void)?

  init(_ action: @escaping (Value) -> Void) {
    self.action = action
  }

  func callAsFunction(_ value: Value) {
    let action = action
    self.action = nil
    action?(value)
  }
}

struct ReverificationNotPresentedError: LocalizedError {
  var errorDescription: String? {
    "Clerk couldn't present reverification because the app shows no window it can present over."
  }
}

struct PresentedReverificationView: View {
  let clerk: Clerk
  let request: ReverificationRequest
  let dismiss: @MainActor () -> Void

  var body: some View {
    ReverificationView(level: request.level) {
      request.markComplete()
    }
    .environment(clerk)
    .environment(\.presentedSheetDismiss, dismiss)
    .presentedAppearance(.shared)
  }
}

#endif
