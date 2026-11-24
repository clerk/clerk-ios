//
//  ReverificationButtons.swift
//  E2EHost
//

import ClerkKit
import ClerkKitUI
import SwiftUI

/// Opens the SDK's reverification sheet the two ways an app can: directly at a level, and
/// through `clerkReverify` around an action the app's backend would protect.
struct ReverificationButtons: View {
  /// How recently the protected action needs a first factor. A backend would check the same
  /// requirement on the session token.
  static let protectedActionRequirement = ReverificationConfig.custom(level: .firstFactor, afterMinutes: 1)

  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkReverify) private var reverify

  @State private var level = SessionVerification.Level.firstFactor
  @State private var isReverifying = false
  @State private var result: String?

  var body: some View {
    VStack(spacing: 12) {
      HStack(spacing: 16) {
        button("Reverify 1FA", level: .firstFactor, identifier: E2EIdentifiers.Home.reverifyFirstFactor)
        button("2FA", level: .secondFactor, identifier: E2EIdentifiers.Home.reverifySecondFactor)
        button("MFA", level: .multiFactor, identifier: E2EIdentifiers.Home.reverifyMultiFactor)
      }

      Button("Protected action") {
        Task { await runProtectedAction() }
      }
      .accessibilityIdentifier(E2EIdentifiers.Home.protectedAction)

      if let result {
        Text(result)
          .accessibilityIdentifier(E2EIdentifiers.Home.reverificationResult)
      }
    }
    .clerkReverification(
      isPresented: $isReverifying,
      level: level,
      onComplete: { result = "Reverified" },
      onCancel: { result = "Reverification cancelled" }
    )
  }

  private func button(_ title: String, level: SessionVerification.Level, identifier: String) -> some View {
    Button(title) {
      result = nil
      self.level = level
      isReverifying = true
    }
    .accessibilityIdentifier(identifier)
  }

  private func runProtectedAction() async {
    result = nil
    do {
      try await reverify {
        guard clerk.has(reverification: Self.protectedActionRequirement) else {
          throw ReverificationRequiredError(reverification: Self.protectedActionRequirement)
        }
      }
      result = "Protected action ran"
    } catch is ReverificationCancelledError {
      result = "Reverification cancelled"
    } catch {
      result = error.localizedDescription
    }
  }
}
