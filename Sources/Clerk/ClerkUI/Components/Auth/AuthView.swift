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
  @Environment(\.clerk) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss
  @State var authState: AuthState
  
  public enum Mode {
    case signInOrUp
    case signIn
    case signUp
  }

  let isDismissable: Bool

  public init(mode: Mode = .signInOrUp, isDismissable: Bool = true) {
    self._authState = State(initialValue: .init(mode: mode))
    self.isDismissable = isDismissable
  }

  public var body: some View {
    NavigationStack(path: $authState.path) {
      AuthStartView()
        .toolbar {
          if isDismissable {
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
              if isDismissable {
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
    .presentationBackground(theme.colors.background)
    .tint(theme.colors.primary)
    .environment(\.authState, authState)
    .task {
      try? await Clerk.Environment.get()
    }
    .task {
      if isDismissable {
        for await event in clerk.authEventEmitter.events {
          switch event {
          case .signInCompleted, .signUpCompleted:
            dismiss()
          }
        }
      }
    }
  }
}

extension AuthView {
  enum Destination: Hashable {
    
    // Auth Start
    case authStart
    
    // Sign In
    case signInFactorOne(factor: Factor)
    case signInFactorOneUseAnotherMethod(currentFactor: Factor)
    case signInFactorTwo(factor: Factor)
    case signInFactorTwoUseAnotherMethod(currentFactor: Factor)
    case signInForgotPassword
    case signInSetNewPassword
    case signInGetHelp
    
    // Sign up
    case signUpCollectField(SignUpCollectFieldView.Field)
    case signUpCode(SignUpCodeView.Field)
    case signUpCompleteProfile
    
    @ViewBuilder
    var view: some View {
      switch self {
      case .authStart:
        AuthStartView()
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
      case .signInForgotPassword:
        SignInFactorOneForgotPasswordView()
      case .signInSetNewPassword:
        SignInSetNewPasswordView()
      case .signInGetHelp:
        SignInGetHelpView()
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
  AuthView(isDismissable: false)
    .environment(\.clerk, .mock)
}

#endif
