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
/// > Important: Mount only one `AuthView` at a time for each `Clerk` instance. A single
/// > `AuthView` can remain mounted while offscreen in a `TabView`; its in-process flow resumes
/// > when it appears again. Don't place separate `AuthView` instances in multiple tabs or present
/// > one over another retained `AuthView`.
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
///       if clerk.isAuthFlowComplete {
///         UserProfileView(isDismissible: false)
///       } else {
///         AuthView(isDismissible: false)
///       }
///     }
///   }
/// }
/// ```
public struct AuthView: View {
  @Environment(Clerk.self) var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) var dismiss
  @Environment(\.clerkAuthFlowCompletionAction) var authFlowCompletionAction
  /// Navigation state for the auth flow.
  @State var navigation = AuthNavigation()

  /// Form field state for auth views.
  @State var authState: AuthState

  /// Configuration values for the auth flow.
  private let config: AuthConfig

  /// Error to present to the user.
  @State private var error: Error?

  /// Keeps this auth flow registered for the view's lifetime.
  @State var authFlowRegistration: AuthFlowRegistration?

  /// Prevents an explicitly finished flow from reacquiring coordinator ownership.
  @State var authFlowRegistrationIsTerminated = false

  /// The conflicting owner already reported for this view.
  @State var reportedConflictingAuthFlowOwnerId: UUID?

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
  ///     button is shown.
  ///     Defaults to `true`.
  public init(mode: Mode = .signInOrUp, isDismissible: Bool = true) {
    self.init(mode: mode, isDismissible: isDismissible, config: AuthConfig())
  }

  init(
    mode: Mode = .signInOrUp,
    isDismissible: Bool = true,
    config: AuthConfig
  ) {
    _authState = State(initialValue: AuthState(mode: mode, config: config))
    self.isDismissible = isDismissible
    self.config = config
  }

  public var body: some View {
    NavigationStack(path: $navigation.path) {
      AuthStartView()
        #if os(iOS)
        .toolbar {
          dismissToolbarItem
        }
        #endif
        .hostBackToolbar()
        .navigationDestination(for: Destination.self) {
          $0.view
            #if os(iOS)
            .toolbar {
              dismissToolbarItem
            }
            #endif
            .authFooter(macOSDismissAction: showDismissButton ? { dismissAuthView() } : nil)
            .environment(navigation)
            .environment(authState)
            .environment(codeLimiter)
        }
        .authFooter(macOSDismissAction: showDismissButton ? { dismissAuthView() } : nil)
    }
    .background(theme.colors.background)
    .presentationBackground(theme.colors.background)
    #if os(macOS)
    .frame(
      width: isDismissible ? 560 : nil,
      height: isDismissible ? 620 : nil,
      alignment: .topLeading
    )
    #endif
    .tint(theme.colors.primary)
    .clerkErrorPresenting($error)
    .environment(navigation)
    .environment(authState)
    .environment(codeLimiter)
    .environment(\.authFlowRequestOwnerId, authFlowRegistration?.id)
    .onAppear {
      registerAuthFlowIfNeeded()
      adoptPendingSessionIfNeeded(clerk.session)
      if let callbackContinuation = clerk.callbackContinuation {
        resumeAuth(callbackContinuation)
      }
    }
    .task {
      let checkpoint = authState.environmentRefreshCheckpoint(for: clerk)
      _ = try? await clerk.ensureEnvironmentRefreshed(after: checkpoint)
    }
    .task {
      for await event in clerk.auth.events {
        switch event {
        case .signInNeedsContinuation(let signIn):
          resumeAuth(.signIn(signIn))
        case .signUpNeedsContinuation(let signUp):
          resumeAuth(.signUp(signUp))
        default:
          break
        }
      }
    }
    .task(id: authFlowReconciliationID) {
      registerAuthFlowIfNeeded()
      await reconcileAuthFlow()
    }
    .onChange(of: clerk.user) { _, newUser in
      guard newUser == nil else { return }

      if isDismissible, navigation.presentedAuthFlowToken != nil {
        dismissAuthView()
      } else {
        navigation.resetForNewAuthFlow()
        resetAuthFlow(owner: authFlowRegistration)
        authFlowRegistrationIsTerminated = false
        registerAuthFlowIfNeeded()
      }
    }
    .onChange(of: config) { _, newConfig in
      authState.configure(newConfig)
    }
    .onOpenURL { url in
      Task {
        do {
          try await clerk.handle(url)
        } catch {
          self.error = error
        }
      }
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

  /// Sets the initial value for the first name field during sign-up.
  ///
  /// - Parameter firstName: The first name to pre-fill.
  /// - Returns: A view with the initial first name configured.
  public func initialFirstName(_ firstName: String) -> AuthView {
    var config = config
    config.initialFirstName = firstName
    return AuthView(mode: authState.mode, isDismissible: isDismissible, config: config)
  }

  /// Sets the initial value for the last name field during sign-up.
  ///
  /// - Parameter lastName: The last name to pre-fill.
  /// - Returns: A view with the initial last name configured.
  public func initialLastName(_ lastName: String) -> AuthView {
    var config = config
    config.initialLastName = lastName
    return AuthView(mode: authState.mode, isDismissible: isDismissible, config: config)
  }

  /// Controls whether configured initial field values can be edited.
  ///
  /// When enabled, non-empty values configured with `initialIdentifier(_:)`,
  /// `initialFirstName(_:)`, or `initialLastName(_:)` are displayed as read-only fields.
  /// Fields without configured initial values remain editable.
  ///
  /// - Parameter locked: Whether to lock configured initial values.
  /// - Returns: A view with prefilled field locking configured.
  public func lockPrefilledFields(_ locked: Bool = true) -> AuthView {
    var config = config
    config.prefilledFieldsAreLocked = locked
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
