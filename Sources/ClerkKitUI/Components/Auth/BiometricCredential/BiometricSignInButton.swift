//
//  BiometricSignInButton.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import LocalAuthentication
import SwiftUI

struct BiometricSignInButton: View {
  @Environment(\.clerkTheme) private var theme

  private let biometryDisplayName: BiometryDisplayName
  private let action: () async -> Void

  init(
    biometryDisplayName: BiometryDisplayName,
    action: @escaping () async -> Void
  ) {
    self.biometryDisplayName = biometryDisplayName
    self.action = action
  }

  var body: some View {
    AsyncButton {
      await action()
    } label: { isRunning in
      label
        .frame(maxWidth: .infinity)
        .overlayProgressView(isActive: isRunning)
    }
    .buttonStyle(.secondary())
    .accessibilityIdentifier(ClerkAccessibilityIdentifiers.Auth.Start.biometricSignInButton)
    .accessibilityLabel(Text("Continue with \(biometryDisplayName.value)", bundle: .module))
  }

  private var label: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 12) {
        if let systemImageName = biometryDisplayName.systemImageName {
          Image(systemName: systemImageName)
            .font(.system(size: 21))
            .frame(width: 21, height: 21)
            .foregroundStyle(theme.colors.foreground)
        }

        Text("Continue with \(biometryDisplayName.value)", bundle: .module)
          .lineLimit(1)
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.foreground)
      }

      Text(biometryDisplayName.value)
        .lineLimit(1)
        .font(theme.fonts.body)
        .foregroundStyle(theme.colors.foreground)
    }
  }
}

#Preview {
  VStack(spacing: 12) {
    BiometricSignInButton(
      biometryDisplayName: .init(biometryType: .faceID),
      action: {}
    )

    BiometricSignInButton(
      biometryDisplayName: .init(biometryType: .touchID),
      action: {}
    )
  }
  .padding()
}

#endif
