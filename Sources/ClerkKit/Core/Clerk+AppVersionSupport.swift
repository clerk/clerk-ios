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

enum AppVersionServerAnswer: Equatable {
  case supported
  case unsupported(Clerk.AppVersionSupportStatus)
}

extension Clerk {
  func applyEnvironmentAppVersionSupport(_ environment: Environment) {
    environmentVersionStatus = versionStatus(in: environment)
    updateAppVersionSupportStatus()
  }

  func applyUnsupportedAppVersion(meta: JSON?, requestSequence: Int? = nil) {
    guard acceptServerVersionAnswer(requestSequence: requestSequence) else { return }
    serverVersionAnswer = .unsupported(AppVersionSupportStatusResolver.resolve(
      unsupportedAppVersionMeta: meta,
      currentVersion: appBuild.version,
      environmentStatus: environmentVersionStatus
    ))
    updateAppVersionSupportStatus()
  }

  func applySupportedAppVersion(requestSequence: Int? = nil) {
    guard acceptServerVersionAnswer(requestSequence: requestSequence) else { return }
    serverVersionAnswer = .supported
    updateAppVersionSupportStatus()
  }

  func resetAppVersionSupport() {
    environmentVersionStatus = nil
    serverVersionAnswer = nil
    serverVersionAnswerRequestSequence = nil
    updateAppVersionSupportStatus()
  }

  private func acceptServerVersionAnswer(requestSequence: Int?) -> Bool {
    guard let requestSequence else { return true }
    if let lastSequence = serverVersionAnswerRequestSequence, requestSequence < lastSequence {
      return false
    }
    serverVersionAnswerRequestSequence = requestSequence
    return true
  }

  private func versionStatus(in environment: Environment) -> AppVersionSupportStatus {
    AppVersionSupportStatusResolver.resolve(
      environment: environment,
      bundleID: appBuild.bundleID,
      currentVersion: appBuild.version
    )
  }

  private func updateAppVersionSupportStatus() {
    let status: AppVersionSupportStatus = switch serverVersionAnswer {
    case let .unsupported(rejection):
      rejection
    case .supported:
      environmentVersionStatus.flatMap { $0.isSupported ? $0 : nil } ?? .supported(currentVersion: appBuild.version)
    case nil:
      environmentVersionStatus ?? .supported(currentVersion: appBuild.version)
    }
    if appVersionSupportStatus != status {
      appVersionSupportStatus = status
    }
  }
}
