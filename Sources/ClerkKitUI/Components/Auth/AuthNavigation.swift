//
//  AuthNavigation.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import Foundation
import SwiftUI

/// Manages navigation state for the authentication flow.
///
/// This class handles navigation path management and routing based on SignIn/SignUp status.
/// It is injected into child views via the environment.
@MainActor
@Observable
final class AuthNavigation {
  /// The navigation path for the auth flow.
  var path: [AuthView.Destination] = []

  /// Set to `true` when a session task flow completes and the auth view should dismiss.
  var sessionTaskComplete = false

  /// Creates a new AuthNavigation instance.
  init() {}

  /// Updates the navigation path based on the current sign-in status.
  ///
  /// - Parameter signIn: The current SignIn object.
  @MainActor
  func setToStepForStatus(signIn: SignIn) {
    switch signIn.status {
    case .complete:
      routeToSessionTaskMfaIfNeeded(createdSessionId: signIn.createdSessionId)
      return
    case .needsIdentifier:
      path = []
    case .needsFirstFactor:
      guard let factor = signIn.startingFirstFactor else {
        ClerkLogger.info("Navigating to GetHelp: No starting first factor available for sign-in", force: true)
        path.append(AuthView.Destination.getHelp(.signIn))
        return
      }
      path.append(AuthView.Destination.signInFactorOne(factor: factor))
    case .needsSecondFactor:
      guard let factor = signIn.startingSecondFactor else {
        ClerkLogger.info("Navigating to GetHelp: No starting second factor available for sign-in", force: true)
        path.append(AuthView.Destination.getHelp(.signIn))
        return
      }

      path.append(AuthView.Destination.signInFactorTwo(factor: factor))
    case .needsNewPassword:
      path.append(AuthView.Destination.signInSetNewPassword)
    case .needsClientTrust:
      guard let factor = signIn.startingSecondFactor else {
        ClerkLogger.info("Navigating to GetHelp: No starting second factor available for client trust", force: true)
        path.append(AuthView.Destination.getHelp(.signIn))
        return
      }
      path.append(AuthView.Destination.signInClientTrust(factor: factor))
    case .unknown:
      return
    }
  }

  /// Updates the navigation path based on the current sign-up status.
  ///
  /// - Parameter signUp: The current SignUp object.
  @MainActor
  func setToStepForStatus(signUp: SignUp) {
    switch signUp.status {
    case .abandoned:
      path = []
    case .missingRequirements:
      handleMissingRequirements(signUp: signUp)
    case .complete:
      routeToSessionTaskMfaIfNeeded(createdSessionId: signUp.createdSessionId)
      return
    case .unknown:
      return
    }
  }

  /// Routes to the forced MFA task flow for the created session when required.
  @MainActor
  private func routeToSessionTaskMfaIfNeeded(createdSessionId: String?) {
    guard let sessionId = createdSessionId else { return }

    if sessionRequiresForcedMfa(sessionId: sessionId) {
      appendSessionTaskMfaIfNeeded()
      return
    }

    Task { @MainActor [weak self] in
      guard let self else { return }

      do {
        _ = try await Clerk.shared.refreshClient()
      } catch {
        ClerkLogger.logError(error, message: "Failed to refresh client while routing to session task MFA")
      }

      guard self.sessionRequiresForcedMfa(sessionId: sessionId) else { return }
      self.appendSessionTaskMfaIfNeeded()
    }
  }

  @MainActor
  private func sessionRequiresForcedMfa(sessionId: String) -> Bool {
    let session = Clerk.shared.client?.sessions.first { $0.id == sessionId }
    return session?.requiresForcedMfa == true
  }

  @MainActor
  private func appendSessionTaskMfaIfNeeded() {
    guard !path.contains(.sessionTaskMfa) else { return }
    path.append(.sessionTaskMfa)
  }

  @MainActor
  private func handleMissingRequirements(signUp: SignUp) {
    if let firstFieldToVerify = signUp.firstFieldToVerify {
      handleFieldToVerify(signUp: signUp, field: firstFieldToVerify)
    } else if let nextFieldToCollect = signUp.firstFieldToCollect {
      handleFieldToCollect(signUp: signUp, field: nextFieldToCollect)
    }
  }

  @MainActor
  private func handleFieldToVerify(signUp: SignUp, field: SignUp.Field) {
    switch field {
    case .emailAddress:
      guard let emailAddress = signUp.emailAddress else {
        path = []
        return
      }
      path.append(AuthView.Destination.signUpCode(.email(emailAddress)))
    case .phoneNumber:
      guard let phoneNumber = signUp.phoneNumber else {
        path = []
        return
      }
      path.append(AuthView.Destination.signUpCode(.phone(phoneNumber)))
    default:
      path = []
    }
  }

  @MainActor
  private func handleFieldToCollect(signUp: SignUp, field: SignUp.Field) {
    switch field {
    case .password:
      path.append(AuthView.Destination.signUpCollectField(.password))
    case .emailAddress:
      path.append(AuthView.Destination.signUpCollectField(.emailAddress))
    case .phoneNumber:
      path.append(AuthView.Destination.signUpCollectField(.phoneNumber))
    case .username:
      path.append(AuthView.Destination.signUpCollectField(.username))
    default:
      if signUp.canCompleteProfileHandleMissingFields {
        path.append(AuthView.Destination.signUpCompleteProfile)
      } else {
        let allSupportedFields = SignUp.individuallyCollectableFields.union(SignUp.completeProfileFields)
        let unsupportedFields = signUp.missingFields.filter { !allSupportedFields.contains($0) }
        let unsupportedFieldStrings = unsupportedFields.map { $0.rawValue }.joined(separator: ", ")
        ClerkLogger.info("Navigating to GetHelp: Sign-up has unsupported missing fields: \(unsupportedFieldStrings)", force: true)
        path.append(AuthView.Destination.getHelp(.signUp))
      }
    }
  }
}

#endif
