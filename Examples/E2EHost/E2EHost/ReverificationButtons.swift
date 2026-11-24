//
//  ReverificationButtons.swift
//  E2EHost
//

import ClerkKit
import ClerkKitUI
import SwiftUI

/// Opens the SDK's reverification sheet through `clerk.reverify`: at a level whatever the session's
/// age, and around an action the app's backend would protect, from the home and from inside a sheet.
struct ReverificationButtons: View {
  /// How recently the protected action needs a first factor. A backend would check the same
  /// requirement on the session token.
  static let protectedActionRequirement = ReverificationConfig.custom(level: .firstFactor, afterMinutes: 1)

  @Environment(Clerk.self) private var clerk

  @State private var protectedActionSheetIsPresented = false
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

      Button("Protected action in a sheet") {
        result = nil
        protectedActionSheetIsPresented = true
      }
      .accessibilityIdentifier(E2EIdentifiers.Home.protectedActionSheet)

      if let result {
        Text(result)
          .accessibilityIdentifier(E2EIdentifiers.Home.reverificationResult)
      }
    }
    .sheet(isPresented: $protectedActionSheetIsPresented) {
      VStack(spacing: 12) {
        Button("Protected action") {
          Task { await runProtectedAction() }
        }
        .accessibilityIdentifier(E2EIdentifiers.ProtectedActionSheet.protectedAction)

        if let result {
          Text(result)
            .accessibilityIdentifier(E2EIdentifiers.ProtectedActionSheet.reverificationResult)
        }
      }
    }
  }

  private func button(_ title: String, level: SessionVerification.Level, identifier: String) -> some View {
    Button(title) {
      Task { await reverify(at: level) }
    }
    .accessibilityIdentifier(identifier)
  }

  /// Asks for reverification at `level` on the first try, so the sheet shows even while the
  /// session is fresh, as it would for an action whose backend asked.
  private func reverify(at level: SessionVerification.Level) async {
    result = nil
    var asked = false
    do {
      try await clerk.reverify {
        guard asked else {
          asked = true
          throw ReverificationRequiredError(reverification: .custom(level: level, afterMinutes: 1))
        }
      }
      result = "Reverified"
    } catch is ReverificationCancelledError {
      result = "Reverification cancelled"
    } catch {
      result = error.localizedDescription
    }
  }

  private func runProtectedAction() async {
    result = nil
    do {
      try await clerk.reverify {
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
