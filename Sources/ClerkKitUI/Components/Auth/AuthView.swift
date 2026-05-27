//
//  AuthView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
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
/// Basic usage as a dismissible sheet:
///
/// ```swift
/// struct HomeView: View {
///   @Environment(Clerk.self) private var clerk
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
/// Full-screen authentication (non-dismissible):
///
/// ```swift
/// struct ProfileView: View {
///   @Environment(Clerk.self) private var clerk
///
///   var body: some View {
///     Group {
///       if clerk.user != nil {
///         UserProfileView(isDismissible: false)
///       } else {
///         AuthView(isDismissible: false)
///       }
///     }
///   }
/// }
/// ```
public struct AuthView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss
  /// Navigation state for the auth flow.
  @State private var navigation = AuthNavigation()

  /// Form field state for auth views.
  @State private var authState: AuthState

  /// Configuration values for the auth flow.
  private let config: AuthConfig

  /// Rate limiter for verification codes.
  @State private var codeLimiter = CodeLimiter()

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

  let isDismissible: Bool

  /// Creates a new authentication view.
  ///
  /// - Parameters:
  ///   - mode: The authentication mode that determines available flows.
  ///     Defaults to `.signInOrUp()` which allows both sign-in and sign-up.
  ///   - isDismissible: Whether the view can be dismissed by the user.
  ///     When `true`, a dismiss button appears and the view automatically
  ///     dismisses on successful authentication. When `false`, no dismiss
  ///     button is shown. Defaults to `true`.
  public init(mode: Mode = .signInOrUp, isDismissible: Bool = true) {
    self.init(mode: mode, isDismissible: isDismissible, config: AuthConfig())
  }

  private init(
    mode: Mode,
    isDismissible: Bool,
    config: AuthConfig
  ) {
    _authState = State(initialValue: AuthState(mode: mode, config: config))
    self.isDismissible = isDismissible
    self.config = config
  }

  public var body: some View {
    NavigationStack(path: $navigation.path) {
      AuthStartView()
        .toolbar {
          dismissToolbarItem
        }
        .navigationDestination(for: Destination.self) { destination in
          destinationView(for: destination)
        }
        .authDevelopmentModeBottomInset()
    }
    .background(theme.colors.background)
    .presentationBackground(theme.colors.background)
    .interactiveDismissDisabled(disablesInteractiveDismissal)
    .tint(theme.colors.primary)
    .environment(navigation)
    .environment(authState)
    .environment(codeLimiter)
    .onAppear {
      navigation.routeToSessionTaskStartIfNeeded(session: clerk.session)
    }
    .task {
      _ = try? await clerk.refreshEnvironment()
    }
    .task {
      for await event in clerk.auth.events {
        switch event {
        case .sessionChanged(let oldValue, let newValue):
          guard !navigation.routeToSessionTaskStartIfNeeded(session: newValue) else { break }
          let becameActive = newValue?.status == .active && (oldValue?.status != .active || oldValue?.id != newValue?.id)
          let isHandlingSessionTask = navigation.hasSessionTaskStartInPath
          let sessionSwitched = oldValue?.id != newValue?.id
          if becameActive, isDismissible, !isHandlingSessionTask || sessionSwitched {
            dismiss()
          }
        default:
          break
        }
      }
    }
    .onChange(of: navigation.allTasksComplete) { _, isComplete in
      guard isComplete else { return }
      if isDismissible {
        dismiss()
      }
    }
    .onChange(of: clerk.session?.tasks) { _, _ in
      navigation.routeToSessionTaskStartIfNeeded(session: clerk.session)
    }
    .onChange(of: clerk.user) { _, newUser in
      guard newUser == nil, navigation.hasSessionTaskStartInPath else { return }
      if isDismissible {
        dismiss()
      } else {
        navigation.path = []
      }
    }
    .onChange(of: config, initial: true) { _, newConfig in
      authState.configure(newConfig)
    }
    .taskOnce {
      await clerk.telemetry.record(
        TelemetryEvents.viewDidAppear(
          "AuthView",
          payload: [
            "mode": .string(authState.mode.rawValue),
            "isDismissible": .bool(isDismissible),
          ]
        )
      )
    }
  }
}

extension AuthView {
  /// Whether the dismiss button should be shown, accounting for required session tasks.
  private var showDismissButton: Bool {
    isDismissible && !navigation.hasSessionTaskStartInPath
  }

  private var disablesInteractiveDismissal: Bool {
    navigation.hasSessionTaskStartInPath && clerk.session?.status != .active
  }

  @ToolbarContentBuilder
  private var dismissToolbarItem: some ToolbarContent {
    if showDismissButton {
      DismissToolbarItem {
        dismiss()
      }
    }
  }

  @ViewBuilder
  private func destinationView(for destination: Destination) -> some View {
    destination.view
      .toolbar {
        dismissToolbarItem
      }
      .authDevelopmentModeBottomInset()
      .environment(navigation)
      .environment(authState)
      .environment(codeLimiter)
  }
}

extension View {
  @ViewBuilder
  fileprivate func authDevelopmentModeBottomInset() -> some View {
    #if os(iOS)
    developmentModeBottomInset(background: .white)
    #elseif os(macOS)
    self
    #endif
  }
}

// MARK: - View Modifiers

extension AuthView {
  /// Sets the initial value for the identifier field on the auth screen.
  ///
  /// The identifier is automatically detected as a phone number or email/username
  /// and routed to the appropriate field.
  ///
  /// - Parameter identifier: The email address, username, or phone number to pre-fill.
  /// - Returns: A view with the initial identifier configured.
  public func initialIdentifier(_ identifier: String) -> AuthView {
    var config = config
    config.initialIdentifier = identifier
    return AuthView(mode: authState.mode, isDismissible: isDismissible, config: config)
  }

  /// Controls whether auth identifier values are persisted between sessions.
  ///
  /// When set to `false`, any previously stored identifiers are cleared and
  /// future changes will not be saved. The default value is `true`.
  ///
  /// - Parameter persists: Whether to persist identifier values to storage.
  /// - Returns: A view with the identifier persistence behavior configured.
  public func persistsIdentifiers(_ persists: Bool) -> AuthView {
    var config = config
    config.persistsIdentifiers = persists
    return AuthView(mode: authState.mode, isDismissible: isDismissible, config: config)
  }

  /// Sets unsafe metadata to attach when this auth flow creates a sign-up.
  ///
  /// This value is scoped to this `AuthView` instance and is only sent with sign-up creation
  /// requests, including sign-in flows that transfer to sign-up.
  ///
  /// - Parameter metadata: The unsafe metadata to attach to created users.
  /// - Returns: A view with the unsafe metadata configured.
  public func unsafeMetadata(_ metadata: JSON?) -> AuthView {
    var config = config
    config.unsafeMetadata = metadata
    return AuthView(mode: authState.mode, isDismissible: isDismissible, config: config)
  }
}

extension AuthView {
  enum Destination: Hashable {
    /// Auth Start
    case authStart

    // Sign In
    case signInFactorOne(factor: Factor)
    case signInFactorOneUseAnotherMethod(currentFactor: Factor)
    case signInFactorTwo(factor: Factor)
    case signInFactorTwoUseAnotherMethod(currentFactor: Factor)
    case signInClientTrust(factor: Factor)
    case signInForgotPassword
    case signInSetNewPassword
    case getHelp(GetHelpView.Context)

    // Sign up
    case signUpCollectField(SignUpCollectFieldView.Field)
    case signUpCode(SignUpCodeView.Field)
    case signUpCompleteProfile

    // Session tasks
    case sessionTaskStart(task: Session.Task)
    case taskMfaSmsChooseNumber
    case taskVerifySms(phoneNumber: PhoneNumber)
    case taskMfaTotp(totpResource: TOTPResource)
    case taskVerifyTotp
    case sessionTaskCreateOrganization(creationDefaults: OrganizationCreationDefaults?)
    case backupCodes(
      backupCodes: [String],
      mfaType: SessionTaskBackupCodesView.BackupCodesMfaType
    )

    @MainActor
    @ViewBuilder
    var view: some View {
      switch self {
      case .authStart:
        AuthStartView()
      case let .signInFactorOne(factor):
        SignInFactorOneView(factor: factor)
      case let .signInFactorOneUseAnotherMethod(currentFactor):
        SignInFactorAlternativeMethodsView(currentFactor: currentFactor)
      case let .signInFactorTwo(factor):
        SignInFactorTwoView(factor: factor)
      case let .signInFactorTwoUseAnotherMethod(currentFactor):
        SignInFactorAlternativeMethodsView(
          currentFactor: currentFactor,
          isSecondFactor: true
        )
      case let .signInClientTrust(factor):
        SignInClientTrustView(factor: factor)
      case .signInForgotPassword:
        SignInFactorOneForgotPasswordView()
      case .signInSetNewPassword:
        SignInSetNewPasswordView()
      case let .getHelp(context):
        GetHelpView(context: context)
      case let .signUpCollectField(field):
        SignUpCollectFieldView(field: field)
      case let .signUpCode(field):
        SignUpCodeView(field: field)
      case .signUpCompleteProfile:
        SignUpCompleteProfileView()
      case .sessionTaskStart(let task):
        SessionTaskStartView(task: task)
      case .taskMfaSmsChooseNumber:
        SessionTaskMfaSmsChooseNumberView()
      case .taskVerifySms(let phoneNumber):
        SessionTaskMfaVerifySmsView(phoneNumber: phoneNumber)
      case .taskMfaTotp(let totpResource):
        SessionTaskMfaTotpView(totp: totpResource)
      case .sessionTaskCreateOrganization(let creationDefaults):
        SessionTaskCreateOrganizationView(creationDefaults: creationDefaults, showBackButton: true)
      case .taskVerifyTotp:
        SessionTaskMfaVerifyTotpView()
      case .backupCodes(let backupCodes, let mfaType):
        SessionTaskBackupCodesView(
          backupCodes: backupCodes,
          mfaType: mfaType
        )
      }
    }
  }
}

#Preview("In sheet") {
  Color.clear
    .sheet(isPresented: .constant(true)) {
      AuthView()
        .clerkPreview()
    }
}

#Preview("Not in sheet") {
  AuthView(isDismissible: false)
    .clerkPreview()
}

#endif
