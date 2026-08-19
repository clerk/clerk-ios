//
//  EmbeddedAuthFlowCompletion.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import SwiftUI

/// Lets a host that embeds ``AuthView`` in its own presentation (e.g. Clerk's Expo
/// SDK) learn that the auth flow finished, so it can close that presentation.
/// A non-dismissible `AuthView` never calls `dismiss()`, so this is the only
/// completion signal such a host receives.
@_spi(FrameworkIntegration)
@MainActor
public struct ClerkAuthFlowCompletionAction {
  private let handler: () -> Void

  public init(_ handler: @escaping () -> Void) {
    self.handler = handler
  }

  func callAsFunction() {
    handler()
  }
}

@_spi(FrameworkIntegration)
extension EnvironmentValues {
  /// The host's action to run when an embedded auth flow completes.
  /// `nil` (the default) leaves the component unchanged.
  @Entry public var clerkAuthFlowCompletionAction: ClerkAuthFlowCompletionAction?
}

#endif
