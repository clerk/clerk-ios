//
//  AuthView+Destination.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

extension AuthView {
  enum Destination: Hashable {
    case authStart

    case signInFactorOne(factor: Factor)
    case signInFactorOneUseAnotherMethod(currentFactor: Factor)
    case signInFactorTwo(factor: Factor)
    case signInFactorTwoUseAnotherMethod(currentFactor: Factor)
    case signInClientTrust(factor: Factor)
    case signInForgotPassword
    case signInSetNewPassword(token: AuthFlowPresentationToken?)
    case getHelp(GetHelpView.Context)

    case signUpCollectField(SignUpCollectFieldView.Field)
    case signUpCode(SignUpCodeView.Field)
    case signUpEmailLink
    case signUpCompleteProfile

    case sessionTaskStart(task: Session.Task, token: AuthFlowPresentationToken)
    case taskMfaSmsChooseNumber(token: AuthFlowPresentationToken)
    case taskVerifySms(phoneNumber: PhoneNumber, token: AuthFlowPresentationToken)
    case taskMfaTotp(totpResource: TOTPResource, token: AuthFlowPresentationToken)
    case taskVerifyTotp(token: AuthFlowPresentationToken)
    case sessionTaskCreateOrganization(
      creationDefaults: OrganizationCreationDefaults?,
      token: AuthFlowPresentationToken
    )
    case backupCodes(
      backupCodes: [String],
      mfaType: SessionTaskBackupCodesView.BackupCodesMfaType,
      token: AuthFlowPresentationToken
    )

    case biometricCredentialEnrollment(
      biometryDisplayName: BiometryDisplayName,
      token: AuthFlowPresentationToken
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
          mode: .secondFactor
        )
      case let .signInClientTrust(factor):
        SignInClientTrustView(factor: factor)
      case .signInForgotPassword:
        SignInFactorOneForgotPasswordView()
      case .signInSetNewPassword(let token):
        SignInSetNewPasswordView(
          mode: token == nil ? .signIn : .sessionTask,
          token: token
        )
      case let .getHelp(context):
        GetHelpView(context: context)
      case let .signUpCollectField(field):
        SignUpCollectFieldView(field: field)
      case let .signUpCode(field):
        SignUpCodeView(field: field)
      case .signUpEmailLink:
        EmailLinkVerificationView(mode: .signUp)
      case .signUpCompleteProfile:
        SignUpCompleteProfileView()
      case .sessionTaskStart(let task, let token):
        SessionTaskStartView(task: task, token: token)
      case .taskMfaSmsChooseNumber(let token):
        SessionTaskMfaSmsChooseNumberView(token: token)
      case .taskVerifySms(let phoneNumber, let token):
        SessionTaskMfaVerifySmsView(phoneNumber: phoneNumber, token: token)
      case .taskMfaTotp(let totpResource, let token):
        SessionTaskMfaTotpView(totp: totpResource, token: token)
      case .sessionTaskCreateOrganization(let creationDefaults, let token):
        SessionTaskCreateOrganizationView(
          creationDefaults: creationDefaults,
          showBackButton: true,
          token: token
        )
      case .taskVerifyTotp(let token):
        SessionTaskMfaVerifyTotpView(token: token)
      case .backupCodes(let backupCodes, let mfaType, let token):
        SessionTaskBackupCodesView(
          backupCodes: backupCodes,
          mfaType: mfaType,
          token: token
        )
      case let .biometricCredentialEnrollment(biometryDisplayName, token):
        BiometricCredentialEnrollmentView(
          biometryDisplayName: biometryDisplayName,
          token: token
        )
      }
    }

    var authFlowPresentationToken: AuthFlowPresentationToken? {
      switch self {
      case .signInSetNewPassword(let token):
        token
      case .sessionTaskStart(_, let token),
           .taskMfaSmsChooseNumber(let token),
           .taskVerifySms(_, let token),
           .taskMfaTotp(_, let token),
           .taskVerifyTotp(let token),
           .sessionTaskCreateOrganization(_, let token),
           .backupCodes(_, _, let token),
           .biometricCredentialEnrollment(_, let token):
        token
      default:
        nil
      }
    }
  }
}

#endif
