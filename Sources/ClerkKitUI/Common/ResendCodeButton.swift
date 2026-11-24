//
//  ResendCodeButton.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import SwiftUI

/// A leaf view that isolates timer-driven countdown updates.
/// Only this view re-renders every second, not the code view that holds it.
struct ResendCodeButton: View {
  let codeLimiter: CodeLimiter
  let identifier: String
  let theme: ClerkTheme
  let action: () async -> Void

  private var remainingSeconds: Int {
    codeLimiter.remainingCooldown(for: identifier)
  }

  var body: some View {
    AsyncButton {
      await action()
    } label: { isRunning in
      HStack(spacing: 2) {
        Text("Didn't receive a code?", bundle: .module)
        Group {
          if remainingSeconds > 0 {
            Text("Resend (\(remainingSeconds))", bundle: .module)
              .foregroundStyle(theme.colors.mutedForeground)
          } else {
            Text("Resend", bundle: .module)
              .foregroundStyle(theme.colors.primary)
          }
        }
        .monospacedDigit()
        .contentTransition(.numericText(countsDown: true))
        .animation(.default, value: remainingSeconds)
      }
      .overlayProgressView(isActive: isRunning)
      .frame(maxWidth: .infinity)
    }
    .buttonStyle(
      .secondary(
        config: .init(
          emphasis: .none,
          size: .small
        )
      )
    )
    .disabled(remainingSeconds > 0)
    .simultaneousGesture(TapGesture())
  }
}

#endif
