//
//  Clerk+AppVersionSupport.swift
//  Clerk
//

import Foundation

struct AppBuild {
  let bundleID: String
  let version: String

  static var current: Self {
    .init(bundleID: DeviceHelper.bundleID, version: DeviceHelper.appVersion)
  }
}

extension Clerk {
  func applySavedEnvironmentAppVersionSupport(_ environment: Environment) {
    environmentVersionStatus = versionStatus(in: environment)
    updateAppVersionSupportStatus()
  }

  func applyFetchedEnvironmentAppVersionSupport(_ environment: Environment, serverVersionAnswersAtRequest: Int) {
    let answeredDuringFetch = serverVersionAnswersAtRequest != serverVersionAnswerCount
    if !answeredDuringFetch || serverVersionStatus?.isSupported != false {
      serverVersionStatus = nil
    }
    environmentVersionStatus = versionStatus(in: environment)
    updateAppVersionSupportStatus()
  }

  func applyUnsupportedAppVersion(meta: JSON?) {
    serverVersionAnswerCount += 1
    serverVersionStatus = AppVersionSupportStatusResolver.resolve(
      unsupportedAppVersionMeta: meta,
      currentVersion: appBuild.version,
      environmentStatus: environmentVersionStatus
    )
    updateAppVersionSupportStatus()
  }

  func applySupportedAppVersion() {
    serverVersionAnswerCount += 1
    if let environmentVersionStatus, environmentVersionStatus.isSupported {
      serverVersionStatus = environmentVersionStatus
    } else {
      serverVersionStatus = .supported(currentVersion: appBuild.version)
    }
    updateAppVersionSupportStatus()
  }

  func resetAppVersionSupport() {
    environmentVersionStatus = nil
    serverVersionStatus = nil
    updateAppVersionSupportStatus()
  }

  private func versionStatus(in environment: Environment) -> AppVersionSupportStatus {
    AppVersionSupportStatusResolver.resolve(
      environment: environment,
      bundleID: appBuild.bundleID,
      currentVersion: appBuild.version
    )
  }

  private func updateAppVersionSupportStatus() {
    let status = serverVersionStatus ?? environmentVersionStatus ?? .supported(currentVersion: appBuild.version)
    if appVersionSupportStatus != status {
      appVersionSupportStatus = status
    }
  }
}
