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
      warnIfUpdateScreenIsMissing()
    }
  }

  private func warnIfUpdateScreenIsMissing() {
    #if DEBUG && (os(iOS) || os(macOS))
    guard appVersionSupport.claimMissingUpdateScreenWarning(
      updateRequiredViewEnabled: options.updateRequiredViewEnabled
    ) else {
      return
    }
    ClerkLogger.warning(Self.missingUpdateScreenWarning, force: true)
    #endif
  }

  static let missingUpdateScreenWarning = """
  This app has a minimum version set, and Clerk rejects requests from builds below it, but the update screen \
  can't show because ClerkKitUI isn't linked. Link ClerkKitUI, or show your own screen from \
  Clerk.shared.appVersionSupportStatus and set updateRequiredViewEnabled to false.
  """
}
