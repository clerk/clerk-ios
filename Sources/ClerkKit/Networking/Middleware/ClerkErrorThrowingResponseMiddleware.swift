//
//  ClerkErrorThrowingResponseMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkErrorThrowingResponseMiddleware: ClerkResponseMiddleware {
  static let appVersionStatusHeader = "X-Clerk-App-Version-Status"
  static let supportedAppVersionStatus = "supported"

  private enum AppVersionResponseVerdict {
    case supported
    case unsupported(Clerk.AppVersionSupportStatus)
  }

  private let runtimeScope: ClerkRuntimeScope
  private let logNetworkError: @Sendable (any Error, String, Int?) -> Void

  init(
    runtimeScope: ClerkRuntimeScope,
    logNetworkError: @escaping @Sendable (any Error, String, Int?) -> Void = { error, endpoint, statusCode in
      ClerkLogger.logNetworkError(error, endpoint: endpoint, statusCode: statusCode)
    }
  ) {
    self.runtimeScope = runtimeScope
    self.logNetworkError = logNetworkError
  }

  func validate(_ response: HTTPURLResponse, data: Data, for request: URLRequest) async throws {
    let clerkAPIError = response.isError ? decodeClerkAPIError(from: data) : nil
    if let verdict = appVersionResponseVerdict(
      response: response,
      request: request,
      clerkAPIError: clerkAPIError
    ) {
      try await runtimeScope.withCurrentClerk { clerk in
        switch verdict {
        case .supported:
          clerk.applySupportedAppVersionResponse(requestSequence: request.clerkRequestSequence)
        case .unsupported(let status):
          clerk.applyUnsupportedAppVersionStatus(
            status,
            requestSequence: request.clerkRequestSequence
          )
        }
      }
    }

    guard response.isError else {
      return
    }

    if let clerkAPIError {
      logNetworkError(
        clerkAPIError,
        response.url?.absoluteString ?? "unknown",
        response.statusCode
      )
      throw clerkAPIError
    }

    let error = URLError(.unknown)
    logNetworkError(
      error,
      response.url?.absoluteString ?? "unknown",
      response.statusCode
    )
    throw error
  }

  private func decodeClerkAPIError(from data: Data) -> ClerkAPIError? {
    guard let response = try? JSONDecoder.clerkDecoder.decode(ClerkErrorResponse.self, from: data),
          var error = response.errors.first
    else {
      return nil
    }

    error.clerkTraceId = response.clerkTraceId
    return error
  }

  private func appVersionResponseVerdict(
    response: HTTPURLResponse,
    request: URLRequest,
    clerkAPIError: ClerkAPIError?
  ) -> AppVersionResponseVerdict? {
    guard !isEnvironmentRequest(request) else {
      return nil
    }

    if response.statusCode == 403,
       let clerkAPIError,
       clerkAPIError.isUnsupportedAppVersion,
       let status = AppVersionSupportStatusResolver.resolveFromUnsupportedAppVersionMeta(
         clerkAPIError.meta,
         requestBundleID: request.value(
           forHTTPHeaderField: ClerkHeaderRequestMiddleware.bundleIDHeader
         ),
         requestVersion: request.value(
           forHTTPHeaderField: ClerkHeaderRequestMiddleware.appVersionHeader
         )
       )
    {
      return .unsupported(status)
    }

    if response.value(forHTTPHeaderField: Self.appVersionStatusHeader)?.lowercased()
      == Self.supportedAppVersionStatus
    {
      return .supported
    }

    return nil
  }

  private func isEnvironmentRequest(_ request: URLRequest) -> Bool {
    request.url?.path.hasSuffix("/v1/environment") == true
  }
}
