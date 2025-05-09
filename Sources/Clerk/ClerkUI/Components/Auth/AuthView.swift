//
//  SignInView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/14/25.
//

#if os(iOS)

import Factory
import SwiftUI

public struct AuthView: View {
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss
  @State var authState = AuthState()

  let showDismissButton: Bool

  public init(showDismissButton: Bool = true) {
    self.showDismissButton = showDismissButton
  }

  public var body: some View {
    NavigationStack(path: $authState.path) {
      SignInStartView()
        .toolbar {
          if showDismissButton {
            ToolbarItem(placement: .topBarTrailing) {
              DismissButton {
                dismiss()
              }
            }
          }
        }
        .navigationDestination(for: Destination.self) {
          $0.view
            .toolbar {
              if showDismissButton {
                ToolbarItem(placement: .topBarTrailing) {
                  DismissButton {
                    dismiss()
                  }
                }
              }
            }
        }
    }
    .background(theme.colors.background)
    .tint(theme.colors.primary)
    .environment(\.authState, authState)
  }
}

extension AuthView {
  enum Destination: Hashable {
    case signInStart
    case signInFactorOne(factor: Factor)
    case signInFactorOneUseAnotherMethod(currentFactor: Factor)
    case signInFactorTwo
    case forgotPassword
    case setNewPassword
    
    @ViewBuilder
    var view: some View {
      switch self {
      case .signInStart:
        SignInStartView()
      case .signInFactorOne(let factor):
        SignInFactorOneView(factor: factor)
      case .signInFactorOneUseAnotherMethod(let currentFactor):
        SignInFactorOneAlternativeMethodsView(currentFactor: currentFactor)
      case .signInFactorTwo:
        Text(verbatim: "Second Factor")
      case .forgotPassword:
        SignInFactorOneForgotPasswordView()
      case .setNewPassword:
        SignInSetNewPasswordView()
      }
    }
  }
}


#Preview("In sheet") {
  Color.clear
    .sheet(isPresented: .constant(true)) {
      AuthView()
        .environment(\.clerk, .mock)
    }
}

#Preview("Not in sheet") {
  AuthView(showDismissButton: false)
    .environment(\.clerk, .mock)
}

#endif
