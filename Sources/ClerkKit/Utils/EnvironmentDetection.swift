//
//  EnvironmentDetection.swift
//  Clerk
//

import Foundation

package enum EnvironmentDetection {
  package static var isRunningInPreviews: Bool {
    #if DEBUG
    return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    #else
    return false
    #endif
  }

  package static var isRunningInTests: Bool {
    #if DEBUG
    let processInfo = ProcessInfo.processInfo
    let hasXCTestRuntime = NSClassFromString("XCTestCase") != nil
      || NSClassFromString("XCTest.XCTestCase") != nil
    let hasTestRunnerSignal = processInfo.arguments.contains("-XCTest")
      || processInfo.arguments.contains(where: { $0.hasSuffix(".xctest") || $0.contains(".xctest/") })
      || processInfo.environment["XCTestConfigurationFilePath"] != nil
    return hasXCTestRuntime || hasTestRunnerSignal
    #else
    return false
    #endif
  }
}
