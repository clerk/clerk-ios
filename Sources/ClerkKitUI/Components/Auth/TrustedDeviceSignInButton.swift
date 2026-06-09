//
//  TrustedDeviceSignInButton.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import LocalAuthentication
import SwiftUI

struct TrustedDeviceSignInButton: View {
  @Environment(\.clerkTheme) private var theme

  private let biometryDisplayName: TrustedDeviceBiometryDisplayName
  private let action: () async -> Void

  init(
    biometryDisplayName: TrustedDeviceBiometryDisplayName = .current(),
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
    .accessibilityIdentifier(ClerkAccessibilityIdentifiers.Auth.Start.trustedDeviceSignInButton)
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
    TrustedDeviceSignInButton(
      biometryDisplayName: .init(biometryType: .faceID),
      action: {}
    )

    TrustedDeviceSignInButton(
      biometryDisplayName: .init(biometryType: .touchID),
      action: {}
    )
  }
  .padding()
}

struct TrustedDeviceBiometryDisplayName: Equatable {
  let value: String
  let systemImageName: String?

  init(biometryType: LABiometryType) {
    systemImageName = biometryType.systemImageName

    switch biometryType {
    case .faceID:
      value = "Face ID"
    case .touchID:
      value = "Touch ID"
    case .opticID:
      value = "Optic ID"
    default:
      value = "biometrics"
    }
  }

  static func current() -> Self {
    let context = LAContext()
    var error: NSError?
    _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    return .init(biometryType: context.biometryType)
  }
}

extension LABiometryType {
  fileprivate var systemImageName: String? {
    switch self {
    case .none:
      nil
    case .touchID:
      "touchid"
    case .faceID:
      "faceid"
    case .opticID:
      "opticid"
    @unknown default:
      nil
    }
  }
}

#endif
