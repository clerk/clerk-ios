//
//  Clerk+AppVersionSupport.swift
//  Clerk
//

import Foundation

extension Clerk {
  func applyEnvironmentAppVersionSupport(_ environment: Environment) {
    updateAppVersionSupport { $0.applyEnvironment(environment) }
  }

  func applyUnsupportedAppVersion(meta: JSON?, requestSequence: Int? = nil) {
    updateAppVersionSupport { $0.applyUnsupported(meta: meta, requestSequence: requestSequence) }
  }

  func applySupportedAppVersion(requestSequence: Int? = nil) {
    updateAppVersionSupport { $0.applySupported(requestSequence: requestSequence) }
  }

  func resetAppVersionSupport() {
    updateAppVersionSupport { $0.reset() }
  }

  private func updateAppVersionSupport(_ change: (inout AppVersionSupportState) -> Void) {
    change(&appVersionSupport)
    let status = appVersionSupport.status
    if appVersionSupportStatus != status {
      appVersionSupportStatus = status
      warnIfUpdateScreenIsMissing(for: status)
    }
  }

  private func warnIfUpdateScreenIsMissing(for status: AppVersionSupportStatus) {
    #if DEBUG
    guard Self.shouldWarnAboutMissingUpdateScreen(
      status: status,
      updateRequiredViewEnabled: options.updateRequiredViewEnabled,
      updateScreenIsAvailable: ClerkAutomaticPresenterLoader.isAvailable,
      alreadyWarned: warnedAboutMissingUpdateScreen
    ) else {
      return
    }
    warnedAboutMissingUpdateScreen = true
    ClerkLogger.warning(Self.missingUpdateScreenWarning, force: true)
    #endif
  }

  static func shouldWarnAboutMissingUpdateScreen(
    status: AppVersionSupportStatus,
    updateRequiredViewEnabled: Bool,
    updateScreenIsAvailable: Bool,
    alreadyWarned: Bool
  ) -> Bool {
    let appHasMinimum = !status.isSupported || status.minimumVersion != nil
    return appHasMinimum && updateRequiredViewEnabled && !updateScreenIsAvailable && !alreadyWarned
  }

  static let missingUpdateScreenWarning = """
  This app has a minimum version set, and Clerk rejects requests from builds below it, but no update screen can \
  show them: ClerkKitUI isn't linked, or this platform has no update screen. Link ClerkKitUI, or show your own \
  screen from Clerk.shared.appVersionSupportStatus and set updateRequiredViewEnabled to false.
  """
}
