//
//  SignInView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/14/25.
//

#if os(iOS)

import FactoryKit
import SwiftUI

/// A comprehensive authentication view that handles user sign-in and sign-up flows.
///
/// `AuthView` provides a complete authentication experience with support for multiple sign-in
/// methods, sign-up flows, multi-factor authentication, password reset, and account recovery.
/// The view can be configured for different authentication modes and automatically handles
/// navigation between authentication steps.
///
/// ## Usage
///
/// Basic usage as a dismissable sheet:
///
/// ```swift
/// struct HomeView: View {
///   @Environment(\.clerk) private var clerk
///   @State private var authIsPresented = false
///
///   var body: some View {
///     ZStack {
///       Group {
///         if clerk.user != nil {
///           UserButton()
///             .frame(width: 36, height: 36)
///         } else {
///           Button("Sign in") {
///             authIsPresented = true
///           }
///         }
///       }
///     }
///     .sheet(isPresented: $authIsPresented) {
///       AuthView()
///     }
///   }
/// }
/// ```
///
/// Full-screen authentication (non-dismissable):
///
/// ```swift
/// struct ProfileView: View {
///   @Environment(\.clerk) private var clerk
///
///   var body: some View {
///     Group {
///       if clerk.user != nil {
///         UserProfileView(isDismissable: false)
///       } else {
///         AuthView(isDismissable: false)
///       }
///     }
///   }
/// }
/// ```
public struct AuthView: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State var authState: AuthState

    /// The authentication mode that determines which flows are available to the user.
    public enum Mode: String {
        /// Allows users to choose between signing in to existing accounts or creating new accounts.
        /// This is the default mode that provides the most flexibility for users.
        case signInOrUp

        /// Restricts the interface to sign-in flows only. Users can only authenticate with existing accounts.
        /// Useful when you want to prevent new account creation in specific contexts.
        case signIn

        /// Restricts the interface to sign-up flows only. Users can only create new accounts.
        /// Useful for dedicated registration flows or when sign-in is handled elsewhere.
        case signUp
    }

    let isDismissable: Bool

    /// Creates a new authentication view.
    ///
    /// - Parameters:
    ///   - mode: The authentication mode that determines available flows.
    ///     Defaults to `.signInOrUp` which allows both sign-in and sign-up.
    ///   - isDismissable: Whether the view can be dismissed by the user.
    ///     When `true`, a dismiss button appears and the view automatically
    ///     dismisses on successful authentication. When `false`, no dismiss
    ///     button is shown. Defaults to `true`.
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
            _ = try? await Clerk.Environment.get()
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
        .taskOnce {
            await clerk.telemetry.record(
                TelemetryEvents.viewDidAppear(
                    "AuthView",
                    payload: [
                        "mode": .string(authState.mode.rawValue),
                        "isDismissable": .bool(isDismissable)
                    ]
                ))
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

        @MainActor
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
