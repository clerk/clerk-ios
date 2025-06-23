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
  @State var authState: AuthState
  
  public enum Mode {
    case signInOrUp
    case signIn
    case signUp
  }

  let showDismissButton: Bool

  public init(mode: Mode = .signInOrUp, showDismissButton: Bool = true) {
    self._authState = State(initialValue: .init(mode: mode))
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
    
    // Sign In
    case signInStart
    case signInFactorOne(factor: Factor)
    case signInFactorOneUseAnotherMethod(currentFactor: Factor)
    case signInFactorTwo(factor: Factor)
    case signInFactorTwoUseAnotherMethod(currentFactor: Factor)
    case forgotPassword
    case setNewPassword
    
    // Sign up
    case signUpCollectField(SignUpCollectFieldView.Field)
    case signUpCode(SignUpCodeView.Field)
    case signUpCompleteProfile
    
    @ViewBuilder
    var view: some View {
      switch self {
      case .signInStart:
        SignInStartView()
      case .signInFactorOne(let factor):
        SignInFactorOneView(factor: factor)
      case .signInFactorOneUseAnotherMethod(let currentFactor):
        SignInFactorAlternativeMethodsView(currentFactor: currentFactor)
      case .signInFactorTwo(let factor):
        SignInFactorTwoView(factor: factor)
      case .signInFactorTwoUseAnotherMethod(let currentFactor):
        SignInFactorAlternativeMethodsView(
          currentFactor: currentFactor,
          isSecondFactor: true
        )
      case .forgotPassword:
        SignInFactorOneForgotPasswordView()
      case .setNewPassword:
        SignInSetNewPasswordView()
      case .signUpCollectField(let field):
        SignUpCollectFieldView(field: field)
      case .signUpCode(let field):
        SignUpCodeView(field: field)
      case .signUpCompleteProfile:
        SignUpCompleteProfileView()
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
