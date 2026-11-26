//
//  ReverificationFlow.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import Foundation

@MainActor
@Observable
final class ReverificationFlow {
  enum Stage: Hashable {
    case firstFactor
    case secondFactor
  }

  enum Destination: Hashable {
    case factor(Factor, Stage)
    case alternativeMethods(currentFactor: Factor, Stage)
    case newPassword(resetFactor: Factor, reason: PasswordResetReason)
    case getHelp
  }

  enum PasswordResetReason: Hashable {
    case pwned
    case compromised

    init?(_ error: Error?) {
      switch (error as? ClerkAPIError)?.code {
      case "form_password_pwned": self = .pwned
      case "form_password_compromised": self = .compromised
      default: return nil
      }
    }
  }

  enum Phase {
    case starting
    case ready(root: Destination)
    case failed(Error)
    case complete
  }

  let level: SessionVerification.Level
  private(set) var session: Session?
  private(set) var verification: SessionVerification?
  private(set) var phase = Phase.starting
  var path: [Destination] = []

  var isComplete: Bool {
    if case .complete = phase { true } else { false }
  }

  var failure: Error? {
    if case .failed(let error) = phase { error } else { nil }
  }

  private(set) var hasLocalBiometricCredential = false

  var newPassword = ""
  var confirmNewPassword = ""
  var signOutOfOtherSessions = false
  var newPasswordError: Error?

  init(level: SessionVerification.Level) {
    self.level = level
  }

  func start(session: Session?, hasLocalBiometricCredential: Bool) async {
    guard case .starting = phase else { return }

    guard let session else {
      phase = .failed(ClerkClientError(message: "You need to be signed in to verify your identity.", localizationBundle: .module))
      return
    }

    self.session = session
    self.hasLocalBiometricCredential = hasLocalBiometricCredential

    do {
      let verification = try await session.startVerification(level: level)
      await handle(verification)
    } catch {
      guard !error.isCancellationError else { return }
      phase = .failed(error)
      ClerkLogger.error("Failed to start reverification", error: error)
    }
  }

  func handle(_ verification: SessionVerification) async {
    do {
      try verification.ensureStatusIsKnown()
    } catch {
      phase = .failed(error)
      return
    }
    self.verification = verification

    switch verification.status {
    case .needsFirstFactor:
      if case .ready = phase { return }
      showRoot(
        Self.startingFactor(
          in: availableFactors(stage: .firstFactor),
          stage: .firstFactor,
          preferredStrategy: Clerk.shared.environment?.displayConfig.preferredSignInStrategy
        ).map { .factor($0, .firstFactor) } ?? .getHelp
      )

    case .needsSecondFactor:
      showRoot(
        Self.startingFactor(
          in: availableFactors(stage: .secondFactor),
          stage: .secondFactor,
          preferredStrategy: nil
        ).map { .factor($0, .secondFactor) } ?? .getHelp
      )

    case .complete:
      if let session {
        _ = try? await session.getToken(.init(skipCache: true))
      }
      phase = .complete

    case .unknown:
      break
    }
  }

  func availableFactors(stage: Stage) -> [Factor] {
    let factors = stage == .firstFactor ? verification?.supportedFirstFactors : verification?.supportedSecondFactors
    return Self.usableFactors(factors ?? [], stage: stage, hasLocalBiometricCredential: hasLocalBiometricCredential)
  }

  func alternativeFactors(to currentFactor: Factor, stage: Stage) -> [Factor] {
    availableFactors(stage: stage).filter { $0 != currentFactor }
  }

  var resetPasswordFactor: Factor? {
    let factors = verification?.supportedFirstFactors ?? []
    return factors.first { $0.strategy == .resetPasswordEmailCode }
      ?? factors.first { $0.strategy == .resetPasswordPhoneCode }
  }

  func rejectNewPassword(_ error: Error) {
    newPasswordError = error
    if case .factor(let factor, _) = path.last, factor.isResetFactor {
      path.removeLast()
    }
  }

  private func showRoot(_ destination: Destination) {
    path = []
    phase = .ready(root: destination)
  }
}

// MARK: - Factor selection

extension ReverificationFlow {
  static func strategyOrder(stage: Stage, preferredStrategy: Clerk.Environment.DisplayConfig.PreferredSignInStrategy?) -> [FactorStrategy] {
    switch stage {
    case .firstFactor where preferredStrategy == .password:
      [.passkey, .biometricCredential, .password, .emailCode, .phoneCode]
    case .firstFactor:
      [.passkey, .biometricCredential, .emailCode, .phoneCode, .password]
    case .secondFactor:
      [.passkey, .biometricCredential, .totp, .phoneCode, .backupCode]
    }
  }

  static func usableFactors(_ factors: [Factor], stage: Stage, hasLocalBiometricCredential: Bool) -> [Factor] {
    let order = strategyOrder(stage: stage, preferredStrategy: nil)
    return factors
      .filter { factor in
        guard order.contains(factor.strategy) else { return false }
        switch factor.strategy {
        case .biometricCredential:
          return hasLocalBiometricCredential
        case .emailCode, .phoneCode:
          return factor.safeIdentifier != nil
        default:
          return true
        }
      }
      .sorted { lhs, rhs in
        let lhsIndex = order.firstIndex(of: lhs.strategy) ?? order.endIndex
        let rhsIndex = order.firstIndex(of: rhs.strategy) ?? order.endIndex
        if lhsIndex != rhsIndex {
          return lhsIndex < rhsIndex
        }
        return (lhs.primary ?? false) && !(rhs.primary ?? false)
      }
  }

  static func startingFactor(
    in factors: [Factor],
    stage: Stage,
    preferredStrategy: Clerk.Environment.DisplayConfig.PreferredSignInStrategy?
  ) -> Factor? {
    let order = strategyOrder(stage: stage, preferredStrategy: preferredStrategy)
    for strategy in order {
      if let factor = factors.first(where: { $0.strategy == strategy }) {
        return factor
      }
    }
    return nil
  }
}

#endif
