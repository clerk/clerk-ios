//
//  View+ClerkReverification.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

/// The error ``ReverifyAction`` throws when the user closes the reverification sheet before verifying.
public struct ReverificationCancelledError: Error, Equatable, Sendable {
  public init() {}
}

/// Asks the user to verify their identity again, presenting ``ReverificationView`` when needed.
///
/// Read it from the environment in a view inside ``SwiftUICore/View/clerkReverificationHost()``:
///
/// ```swift
/// @Environment(\.clerkReverify) private var reverify
///
/// func transfer() async {
///   do {
///     try await reverify {
///       try await api.transferFunds()
///     }
///   } catch is ReverificationCancelledError {
///     // The user closed the sheet.
///   } catch {
///     // Show the error.
///   }
/// }
/// ```
public struct ReverifyAction: Sendable {
  private let isSatisfied: @MainActor @Sendable (ReverificationConfig) -> Bool
  private let present: @MainActor @Sendable (SessionVerification.Level) async throws -> Void

  init(
    isSatisfied: @escaping @MainActor @Sendable (ReverificationConfig) -> Bool,
    present: @escaping @MainActor @Sendable (SessionVerification.Level) async throws -> Void
  ) {
    self.isSatisfied = isSatisfied
    self.present = present
  }

  /// Returns once the user has verified within `reverification`, presenting the reverification
  /// sheet only when ``Clerk/has(reverification:)`` is `false`.
  ///
  /// - Throws: ``ReverificationCancelledError`` when the user closes the sheet.
  @MainActor
  public func callAsFunction(_ reverification: ReverificationConfig) async throws {
    guard !isSatisfied(reverification) else { return }
    try await present(reverification.requirement?.level ?? .secondFactor)
  }

  /// Runs `operation`, and when it throws an error that asks for reverification, asks the user
  /// to verify and runs `operation` once more.
  ///
  /// An error asks for reverification when ``ReverificationRequiredError/init(_:)`` recognizes
  /// it: a ``ReverificationRequiredError`` your code throws, or Clerk's
  /// `session_reverification_required` API error.
  ///
  /// - Throws: ``ReverificationCancelledError`` when the user closes the sheet, or the error
  ///   `operation` throws.
  @MainActor
  public func callAsFunction<T>(_ operation: @MainActor () async throws -> T) async throws -> T {
    do {
      return try await operation()
    } catch {
      guard let required = ReverificationRequiredError(error) else { throw error }
      try await present(required.reverification?.requirement?.level ?? .secondFactor)
      return try await operation()
    }
  }

  static let missingHost = ReverifyAction(isSatisfied: { _ in false }) { _ in
    ClerkLogger.error("Reverification has no host", error: ReverificationHostMissingError())
    throw ReverificationHostMissingError()
  }
}

/// A setup mistake in the app, so its description is for the developer and stays in English.
struct ReverificationHostMissingError: LocalizedError {
  var errorDescription: String? {
    "clerkReverify needs clerkReverificationHost() on a view above the one that calls it."
  }
}

extension EnvironmentValues {
  /// Asks the user to verify their identity again. Available inside ``SwiftUICore/View/clerkReverificationHost()``.
  @Entry public var clerkReverify = ReverifyAction.missingHost
}

extension View {
  /// Presents ``ReverificationView`` as a sheet when `isPresented` is `true`.
  ///
  /// - Parameters:
  ///   - isPresented: Whether the sheet is presented. It's set to `false` when the sheet closes.
  ///   - level: The factors the user has to verify. Defaults to `.secondFactor`.
  ///   - onComplete: Runs once the verification completes, right before the sheet closes.
  ///   - onCancel: Runs when the user closes the sheet before verifying.
  public func clerkReverification(
    isPresented: Binding<Bool>,
    level: SessionVerification.Level = .secondFactor,
    onComplete: @escaping @MainActor () -> Void,
    onCancel: (@MainActor () -> Void)? = nil
  ) -> some View {
    modifier(
      ReverificationSheetModifier(
        isPresented: isPresented,
        level: level,
        onComplete: onComplete,
        onCancel: onCancel
      )
    )
  }

  /// Lets views inside this one call ``EnvironmentValues/clerkReverify``, which presents the
  /// reverification sheet from here.
  ///
  /// Add it once, near the root of your app's signed-in content.
  public func clerkReverificationHost() -> some View {
    modifier(ReverificationHostModifier())
  }
}

private struct ReverificationSheetModifier: ViewModifier {
  @Binding var isPresented: Bool
  let level: SessionVerification.Level
  let onComplete: @MainActor () -> Void
  let onCancel: (@MainActor () -> Void)?

  @State private var didComplete = false

  func body(content: Content) -> some View {
    content
      .clerkSheet(
        isPresented: $isPresented,
        onDismiss: {
          if !didComplete {
            onCancel?()
          }
          didComplete = false
        },
        content: {
          ReverificationView(level: level) {
            didComplete = true
            onComplete()
          }
        }
      )
  }
}

@MainActor
@Observable
final class ReverificationRequest: Identifiable {
  let id = UUID()
  let level: SessionVerification.Level
  private var continuations: [CheckedContinuation<Void, Error>] = []
  private(set) var didComplete = false

  init(level: SessionVerification.Level) {
    self.level = level
  }

  func wait() async throws {
    try await withCheckedThrowingContinuation { continuations.append($0) }
  }

  func markComplete() {
    didComplete = true
  }

  func finish() {
    let result: Result<Void, Error> = didComplete ? .success(()) : .failure(ReverificationCancelledError())
    let waiting = continuations
    continuations = []
    waiting.forEach { $0.resume(with: result) }
  }
}

@MainActor
@Observable
final class ReverificationPresenter {
  var presented: ReverificationRequest?
  private var active: ReverificationRequest?

  /// Presents the sheet, or joins the one already presented, and returns once it closes.
  func present(level: SessionVerification.Level) async throws {
    let request = active ?? ReverificationRequest(level: level)
    if active == nil {
      active = request
      presented = request
    }
    try await request.wait()
  }

  func sheetDidDismiss() {
    let request = active
    active = nil
    request?.finish()
  }
}

private struct ReverificationHostModifier: ViewModifier {
  @Environment(Clerk.self) private var clerk
  @State private var presenter = ReverificationPresenter()

  func body(content: Content) -> some View {
    @Bindable var presenter = presenter

    content
      .environment(
        \.clerkReverify,
        ReverifyAction(
          isSatisfied: { [clerk] in clerk.has(reverification: $0) },
          present: { [presenter] in try await presenter.present(level: $0) }
        )
      )
      .clerkSheet(item: $presenter.presented, onDismiss: presenter.sheetDidDismiss) { request in
        ReverificationView(level: request.level) {
          request.markComplete()
        }
      }
  }
}

#endif
