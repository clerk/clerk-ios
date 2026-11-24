//
//  ReverificationView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

/// A view that asks the signed-in user to verify their identity again before a sensitive action.
///
/// `ReverificationView` starts a session reverification at `level`, shows a screen for each factor
/// the user has to verify, and lets the user switch to another method they have. When the
/// verification completes, it refreshes the session token, so ``Clerk/has(reverification:)``
/// and your backend see the new verification, calls `onComplete`, and dismisses itself.
///
/// Present it as a sheet with ``SwiftUICore/View/clerkReverification(isPresented:level:onComplete:onCancel:)``,
/// or let ``Clerk/reverify(_:)`` present it when an action needs it.
///
/// ```swift
/// .sheet(isPresented: $isReverifying) {
///   ReverificationView(level: .secondFactor) {
///     Task { try await transferFunds() }
///   }
/// }
/// ```
public struct ReverificationView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  private var dismiss = ClerkDismissAction()

  @State private var flow: ReverificationFlow
  @State private var codeLimiter = CodeLimiter()

  private let onComplete: @MainActor () -> Void

  /// Creates a reverification view.
  ///
  /// - Parameters:
  ///   - level: The factors the user has to verify. Defaults to `.secondFactor`, which Clerk
  ///     lowers to a first factor for a user with no second factor.
  ///   - onComplete: Runs once the verification completes and the session token is refreshed,
  ///     right before the view dismisses itself.
  public init(
    level: SessionVerification.Level = .secondFactor,
    onComplete: @escaping @MainActor () -> Void = {}
  ) {
    _flow = State(initialValue: ReverificationFlow(level: level))
    self.onComplete = onComplete
  }

  public var body: some View {
    NavigationStack(path: $flow.path) {
      rootContent
        #if os(iOS)
        .toolbar {
          DismissToolbarItem()
        }
        #endif
        .navigationDestination(for: ReverificationFlow.Destination.self) { destination in
          ReverificationDestinationView(destination: destination)
            #if os(iOS)
            .toolbar {
              DismissToolbarItem()
            }
            #endif
            .authFooter(macOSDismissAction: { dismiss() })
        }
        .authFooter(macOSDismissAction: { dismiss() })
    }
    .background(theme.colors.background)
    .presentationBackground(theme.colors.background)
    #if os(macOS)
    .frame(width: 560, height: 620, alignment: .topLeading)
    #endif
    .tint(theme.colors.primary)
    .environment(flow)
    .environment(codeLimiter)
    .task {
      await flow.start(
        session: clerk.session,
        hasLocalBiometricCredential: (try? clerk.biometricCredentials.currentUserLocalAvailability().isAvailable) ?? false
      )
    }
    .onChange(of: flow.isComplete) { _, isComplete in
      guard isComplete else { return }
      onComplete()
      dismiss()
    }
    .taskOnce {
      await clerk.telemetry.record(
        TelemetryEvents.viewDidAppear(
          "ReverificationView",
          payload: ["level": .string(flow.level.rawValue)]
        )
      )
    }
  }

  @ViewBuilder
  private var rootContent: some View {
    switch flow.phase {
    case .starting, .complete:
      SpinnerView()
        .frame(width: 32, height: 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colors.background)
    case .ready(let root):
      ReverificationDestinationView(destination: root)
        .id(root)
    case .failed(let error):
      ScrollView {
        ErrorView(error: error)
          .padding(16)
      }
      .background(theme.colors.background)
    }
  }
}

struct ReverificationDestinationView: View {
  let destination: ReverificationFlow.Destination

  var body: some View {
    switch destination {
    case .factor(let factor, let stage):
      switch factor.strategy {
      case .password:
        ReverificationPasswordView(factor: factor)
      case .passkey:
        ReverificationPasskeyView(factor: factor, stage: stage)
      case .biometricCredential:
        ReverificationBiometricView(factor: factor, stage: stage)
      case .backupCode:
        ReverificationBackupCodeView(factor: factor)
      default:
        ReverificationCodeView(factor: factor, stage: stage)
      }
    case .alternativeMethods(let currentFactor, let stage):
      ReverificationAlternativeMethodsView(currentFactor: currentFactor, stage: stage)
    case .newPassword(let resetFactor):
      ReverificationNewPasswordView(resetFactor: resetFactor)
    case .getHelp:
      GetHelpView(context: .reverification)
    }
  }
}

#Preview {
  Color.clear
    .clerkSheet(isPresented: .constant(true)) {
      ReverificationView()
        .clerkPreview()
    }
}

#endif
