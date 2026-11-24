//
//  View+ClerkReverification.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

/// The error ``Clerk/reverify(_:)`` throws when the user closes the reverification sheet before verifying.
public struct ReverificationCancelledError: Error, Equatable, Sendable {
  public init() {}
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

#endif
