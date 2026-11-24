//
//  ReverificationView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct ReverificationView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  private var dismiss = ClerkDismissAction()

  @State private var flow: ReverificationFlow
  @State private var codeLimiter = CodeLimiter()

  private let onComplete: @MainActor () -> Void

  init(
    level: SessionVerification.Level = .secondFactor,
    onComplete: @escaping @MainActor () -> Void = {}
  ) {
    _flow = State(initialValue: ReverificationFlow(level: level))
    self.onComplete = onComplete
  }

  var body: some View {
    NavigationStack(path: $flow.path) {
      rootContent
        #if os(iOS)
        .toolbar {
          dismissToolbarItem
        }
        #endif
        .navigationDestination(for: ReverificationFlow.Destination.self) { destination in
          ReverificationDestinationView(destination: destination)
            #if os(iOS)
            .toolbar {
              dismissToolbarItem
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

  private var dismissToolbarItem: some ToolbarContent {
    DismissToolbarItem {
      dismiss()
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
