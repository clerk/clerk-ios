//
//  AppVersionSupportState.swift
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

struct AppVersionSupportState {
  private enum ServerAnswer {
    case supported
    case unsupported(meta: JSON?)
  }

  var appBuild = AppBuild.current
  private var environmentStatus: Clerk.AppVersionSupportStatus?
  private var serverAnswer: ServerAnswer?
  private var lastAnswerRequestSequence: Int?

  var status: Clerk.AppVersionSupportStatus {
    switch serverAnswer {
    case let .unsupported(meta):
      AppVersionSupportStatusResolver.resolve(
        unsupportedAppVersionMeta: meta,
        currentVersion: appBuild.version,
        environmentStatus: environmentStatus
      )
    case .supported:
      environmentStatus.flatMap { $0.isSupported ? $0 : nil } ?? .supported(currentVersion: appBuild.version)
    case nil:
      environmentStatus ?? .supported(currentVersion: appBuild.version)
    }
  }

  mutating func applyEnvironment(_ environment: Clerk.Environment) {
    environmentStatus = AppVersionSupportStatusResolver.resolve(
      environment: environment,
      bundleID: appBuild.bundleID,
      currentVersion: appBuild.version
    )
  }

  mutating func applyUnsupported(meta: JSON?, requestSequence: Int?) {
    guard acceptAnswer(requestSequence: requestSequence) else { return }
    serverAnswer = .unsupported(meta: meta)
  }

  mutating func applySupported(requestSequence: Int?) {
    guard acceptAnswer(requestSequence: requestSequence) else { return }
    serverAnswer = .supported
  }

  mutating func reset() {
    environmentStatus = nil
    serverAnswer = nil
    lastAnswerRequestSequence = nil
  }

  private mutating func acceptAnswer(requestSequence: Int?) -> Bool {
    guard let requestSequence else { return true }
    if let lastAnswerRequestSequence, requestSequence < lastAnswerRequestSequence {
      return false
    }
    lastAnswerRequestSequence = requestSequence
    return true
  }
}
