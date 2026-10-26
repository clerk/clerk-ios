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
    }
  }
}
