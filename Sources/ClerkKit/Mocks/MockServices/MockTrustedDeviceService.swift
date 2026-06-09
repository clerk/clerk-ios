//
//  MockTrustedDeviceService.swift
//  Clerk
//

import Foundation

package final class MockTrustedDeviceService: TrustedDeviceServiceProtocol {
  package nonisolated(unsafe) var listHandler: (() async throws -> [TrustedDevice])?
  package nonisolated(unsafe) var prepareEnrollmentHandler: ((TrustedDevice.PrepareEnrollmentParams) async throws -> TrustedDeviceChallenge)?
  package nonisolated(unsafe) var attemptEnrollmentHandler: ((TrustedDevice.AttemptEnrollmentParams) async throws -> TrustedDevice)?
  package nonisolated(unsafe) var revokeHandler: ((String) async throws -> TrustedDevice)?

  package init(
    list: (() async throws -> [TrustedDevice])? = nil,
    prepareEnrollment: ((TrustedDevice.PrepareEnrollmentParams) async throws -> TrustedDeviceChallenge)? = nil,
    attemptEnrollment: ((TrustedDevice.AttemptEnrollmentParams) async throws -> TrustedDevice)? = nil,
    revoke: ((String) async throws -> TrustedDevice)? = nil
  ) {
    listHandler = list
    prepareEnrollmentHandler = prepareEnrollment
    attemptEnrollmentHandler = attemptEnrollment
    revokeHandler = revoke
  }

  @MainActor
  package func list() async throws -> [TrustedDevice] {
    if let handler = listHandler {
      return try await handler()
    }
    return [.mock]
  }

  @MainActor
  package func prepareEnrollment(params: TrustedDevice.PrepareEnrollmentParams) async throws -> TrustedDeviceChallenge {
    if let handler = prepareEnrollmentHandler {
      return try await handler(params)
    }
    return .mock
  }

  @MainActor
  package func attemptEnrollment(params: TrustedDevice.AttemptEnrollmentParams) async throws -> TrustedDevice {
    if let handler = attemptEnrollmentHandler {
      return try await handler(params)
    }
    return .mock
  }

  @MainActor
  package func revoke(trustedDeviceId: String) async throws -> TrustedDevice {
    if let handler = revokeHandler {
      return try await handler(trustedDeviceId)
    }
    return .mock
  }
}
