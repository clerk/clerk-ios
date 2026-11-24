//
//  ReverificationAlternativeMethodsView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct ReverificationAlternativeMethodsView: View {
  @Environment(\.clerkTheme) private var theme
  @Environment(ReverificationFlow.self) private var flow

  let currentFactor: Factor
  let stage: ReverificationFlow.Stage

  @State private var biometryDisplayName = BiometryDisplayName.current()

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Use another method")
          HeaderView(style: .subtitle, text: "Facing issues? You can use any of these methods to verify your identity.")
        }
        .padding(.bottom, 32)

        VStack(spacing: 16) {
          ForEach(flow.alternativeFactors(to: currentFactor, stage: stage), id: \.self) { factor in
            Button {
              flow.path.append(.factor(factor, stage))
            } label: {
              StrategyOptionButton(iconName: iconName(factor: factor), text: actionText(factor: factor))
            }
            .buttonStyle(.secondary())
            .accessibilityIdentifier(
              ClerkAccessibilityIdentifiers.Reverification.alternativeMethodButton(strategy: factor.strategy.rawValue)
            )
            .simultaneousGesture(TapGesture())
          }
        }
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(16)
    }
    .background(theme.colors.background)
  }

  private func actionText(factor: Factor) -> LocalizedStringKey {
    let identifier = factor.safeIdentifier ?? ""
    return switch factor.strategy {
    case .emailCode:
      "Email code to \(identifier)"
    case .phoneCode:
      "Send SMS code to \(identifier.formattedAsPhoneNumberIfPossible)"
    case .passkey:
      "Use your passkey"
    case .password:
      "Use your password"
    case .biometricCredential:
      "Use \(biometryDisplayName.value)"
    case .totp:
      "Use your authenticator app"
    default:
      "Use a backup code"
    }
  }

  private func iconName(factor: Factor) -> String {
    switch factor.strategy {
    case .emailCode:
      "icon-email"
    case .phoneCode:
      "icon-sms"
    case .passkey, .biometricCredential:
      "icon-fingerprint"
    case .totp:
      "icon-key"
    default:
      "icon-lock"
    }
  }
}

/// Opens the other methods the user can verify with, when there are any.
struct ReverificationUseAnotherMethodButton: View {
  @Environment(ReverificationFlow.self) private var flow

  let factor: Factor
  let stage: ReverificationFlow.Stage

  var body: some View {
    if !flow.alternativeFactors(to: factor, stage: stage).isEmpty {
      Button {
        flow.path.append(.alternativeMethods(currentFactor: factor, stage))
      } label: {
        Text("Use another method", bundle: .module)
      }
      .buttonStyle(.primary(config: .init(emphasis: .none, size: .small)))
      .accessibilityIdentifier(ClerkAccessibilityIdentifiers.Reverification.useAnotherMethodButton)
      .simultaneousGesture(TapGesture())
    }
  }
}

#Preview {
  ReverificationAlternativeMethodsView(currentFactor: .mockPassword, stage: .firstFactor)
    .environment(ReverificationFlow(level: .firstFactor))
    .clerkPreview()
}

#endif
