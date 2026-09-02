@testable import ClerkKit
import Foundation
import Testing

@MainActor
struct ClerkErrorThrowingResponseMiddlewareTests {
  @Test
  func unsupportedAppVersionUpdatesStatusBeforeThrowing() async throws {
    let clerk = Clerk()
    let middleware = makeMiddleware(for: clerk)
    let request = try makeRequest(path: "/v1/client", sequence: 1)
    let response = try makeResponse(for: request, statusCode: 403)

    await #expect(throws: ClerkAPIError.self) {
      try await middleware.validate(response, data: unsupportedPayload, for: request)
    }

    #expect(!clerk.appVersionSupportStatus.isSupported)
    #expect(clerk.appVersionSupportStatus.minimumVersion == "2.0.0")
  }

  @Test
  func serverVerdictsRemainAuthoritativeOverFreshEnvironmentPolicies() async throws {
    let appBundleID = "com.example.middleware-force-update"
    let environmentService = MockEnvironmentService(get: {
      Self.environment(
        bundleID: appBundleID,
        minimumVersion: "999.0.0"
      )
    })
    let clerk = Clerk(appBundleID: appBundleID, appVersion: "1.0.0")
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      environmentService: environmentService
    )
    let middleware = makeMiddleware(for: clerk)
    _ = try await clerk.refreshEnvironment()
    #expect(!clerk.appVersionSupportStatus.isSupported)

    let supportedRequest = try makeRequest(path: "/v1/client", sequence: 1)
    let supportedResponse = try makeResponse(
      for: supportedRequest,
      statusCode: 200,
      appVersionStatus: "supported"
    )
    try await middleware.validate(supportedResponse, data: Data(), for: supportedRequest)

    _ = try await clerk.refreshEnvironment()
    #expect(clerk.appVersionSupportStatus == .supportedDefault)

    let unsupportedRequest = try makeRequest(
      path: "/v1/client",
      sequence: 2,
      bundleID: appBundleID
    )
    let unsupportedResponse = try makeResponse(for: unsupportedRequest, statusCode: 403)

    await #expect(throws: ClerkAPIError.self) {
      try await middleware.validate(
        unsupportedResponse,
        data: unsupportedPayload(appIdentifier: appBundleID),
        for: unsupportedRequest
      )
    }

    environmentService.getHandler = { .mock }
    _ = try await clerk.refreshEnvironment()

    #expect(!clerk.appVersionSupportStatus.isSupported)
    #expect(clerk.appVersionSupportStatus.minimumVersion == "2.0.0")
  }

  @Test
  func supportedMarkerOverridesStaleUnsupportedEnvironmentPolicy() async throws {
    let clerk = Clerk()
    let middleware = makeMiddleware(for: clerk)
    clerk.appVersionSupportStatus = unsupportedStatus
    #expect(!clerk.appVersionSupportStatus.isSupported)

    let successfulRequest = try makeRequest(path: "/v1/client", sequence: 1)
    let successfulResponse = try makeResponse(
      for: successfulRequest,
      statusCode: 200,
      appVersionStatus: "supported"
    )
    try await middleware.validate(successfulResponse, data: Data(), for: successfulRequest)

    #expect(clerk.appVersionSupportStatus == .supportedDefault)
    #expect(
      clerk.resolvedAppVersionSupportStatus(environmentStatus: unsupportedStatus)
        == .supportedDefault
    )
  }

  @Test
  func successfulResponseWithoutMarkerDoesNotClearServerEnforcedStatus() async throws {
    let clerk = Clerk()
    let middleware = makeMiddleware(for: clerk)
    let unsupportedRequest = try makeRequest(path: "/v1/client", sequence: 1)
    let unsupportedResponse = try makeResponse(for: unsupportedRequest, statusCode: 403)

    await #expect(throws: ClerkAPIError.self) {
      try await middleware.validate(unsupportedResponse, data: unsupportedPayload, for: unsupportedRequest)
    }

    let successfulRequest = try makeRequest(path: "/v1/client", sequence: 2)
    let successfulResponse = try makeResponse(for: successfulRequest, statusCode: 200)
    try await middleware.validate(successfulResponse, data: Data(), for: successfulRequest)

    #expect(!clerk.appVersionSupportStatus.isSupported)
  }

  @Test
  func successfulEnvironmentResponseDoesNotApplySupportedMarker() async throws {
    let clerk = Clerk()
    let middleware = makeMiddleware(for: clerk)
    let unsupportedRequest = try makeRequest(path: "/v1/client", sequence: 1)
    let unsupportedResponse = try makeResponse(for: unsupportedRequest, statusCode: 403)

    await #expect(throws: ClerkAPIError.self) {
      try await middleware.validate(unsupportedResponse, data: unsupportedPayload, for: unsupportedRequest)
    }

    let environmentRequest = try makeRequest(path: "/v1/environment", sequence: 2)
    let environmentResponse = try makeResponse(
      for: environmentRequest,
      statusCode: 200,
      appVersionStatus: "supported"
    )
    try await middleware.validate(environmentResponse, data: Data(), for: environmentRequest)

    #expect(!clerk.appVersionSupportStatus.isSupported)
  }

  @Test
  func newerUnsupportedResponseOverridesSupportedVerdict() async throws {
    let clerk = Clerk()
    let middleware = makeMiddleware(for: clerk)
    let successfulRequest = try makeRequest(path: "/v1/client", sequence: 1)
    let successfulResponse = try makeResponse(
      for: successfulRequest,
      statusCode: 200,
      appVersionStatus: "supported"
    )
    try await middleware.validate(successfulResponse, data: Data(), for: successfulRequest)

    let unsupportedRequest = try makeRequest(path: "/v1/client", sequence: 2)
    let unsupportedResponse = try makeResponse(for: unsupportedRequest, statusCode: 403)
    await #expect(throws: ClerkAPIError.self) {
      try await middleware.validate(unsupportedResponse, data: unsupportedPayload, for: unsupportedRequest)
    }

    #expect(!clerk.appVersionSupportStatus.isSupported)
  }

  @Test
  func retryAttemptWithSameSequenceCanBlockAfterSupportedMarker() async throws {
    let clerk = Clerk()
    let middleware = makeMiddleware(for: clerk)
    let firstAttempt = try makeRequest(path: "/v1/client", sequence: 1)
    let retryableResponse = try makeResponse(
      for: firstAttempt,
      statusCode: 503,
      appVersionStatus: "supported"
    )

    await #expect(throws: ClerkAPIError.self) {
      try await middleware.validate(
        retryableResponse,
        data: apiErrorPayload,
        for: firstAttempt
      )
    }
    #expect(clerk.appVersionSupportStatus == .supportedDefault)

    let retryAttempt = try makeRequest(path: "/v1/client", sequence: 1)
    let unsupportedResponse = try makeResponse(for: retryAttempt, statusCode: 403)
    await #expect(throws: ClerkAPIError.self) {
      try await middleware.validate(
        unsupportedResponse,
        data: unsupportedPayload,
        for: retryAttempt
      )
    }

    #expect(!clerk.appVersionSupportStatus.isSupported)
    #expect(clerk.appVersionSupportStatus.minimumVersion == "2.0.0")
  }

  @Test
  func olderSupportedResponseDoesNotOverrideNewerUnsupportedVerdict() async throws {
    let clerk = Clerk()
    let middleware = makeMiddleware(for: clerk)
    let unsupportedRequest = try makeRequest(path: "/v1/client", sequence: 2)
    let unsupportedResponse = try makeResponse(for: unsupportedRequest, statusCode: 403)

    await #expect(throws: ClerkAPIError.self) {
      try await middleware.validate(unsupportedResponse, data: unsupportedPayload, for: unsupportedRequest)
    }

    let olderRequest = try makeRequest(path: "/v1/client/sessions", sequence: 1)
    let olderResponse = try makeResponse(
      for: olderRequest,
      statusCode: 200,
      appVersionStatus: "supported"
    )
    try await middleware.validate(olderResponse, data: Data(), for: olderRequest)

    #expect(!clerk.appVersionSupportStatus.isSupported)
  }

  @Test
  func olderUnsupportedResponseDoesNotOverrideNewerSupportedVerdict() async throws {
    let clerk = Clerk()
    let middleware = makeMiddleware(for: clerk)
    clerk.appVersionSupportStatus = unsupportedStatus

    let successfulRequest = try makeRequest(path: "/v1/client/sessions", sequence: 2)
    let successfulResponse = try makeResponse(
      for: successfulRequest,
      statusCode: 200,
      appVersionStatus: "supported"
    )
    try await middleware.validate(successfulResponse, data: Data(), for: successfulRequest)

    let olderRequest = try makeRequest(path: "/v1/client", sequence: 1)
    let olderResponse = try makeResponse(for: olderRequest, statusCode: 403)
    await #expect(throws: ClerkAPIError.self) {
      try await middleware.validate(olderResponse, data: unsupportedPayload, for: olderRequest)
    }

    #expect(clerk.appVersionSupportStatus.isSupported)
  }

  @Test
  func supportedMarkerOnAPIErrorClearsBlockBeforeThrowing() async throws {
    let clerk = Clerk()
    let middleware = makeMiddleware(for: clerk)
    clerk.appVersionSupportStatus = unsupportedStatus
    let request = try makeRequest(path: "/v1/client", sequence: 1)
    let response = try makeResponse(
      for: request,
      statusCode: 422,
      appVersionStatus: "supported"
    )

    await #expect(throws: ClerkAPIError.self) {
      try await middleware.validate(response, data: apiErrorPayload, for: request)
    }

    #expect(clerk.appVersionSupportStatus == .supportedDefault)
  }

  @Test
  func validUnsupportedErrorWinsOverSupportedMarker() async throws {
    let clerk = Clerk()
    let middleware = makeMiddleware(for: clerk)
    let request = try makeRequest(path: "/v1/client", sequence: 1)
    let response = try makeResponse(
      for: request,
      statusCode: 403,
      appVersionStatus: "supported"
    )

    await #expect(throws: ClerkAPIError.self) {
      try await middleware.validate(response, data: unsupportedPayload, for: request)
    }

    #expect(!clerk.appVersionSupportStatus.isSupported)
    #expect(clerk.appVersionSupportStatus.minimumVersion == "2.0.0")
  }

  @Test
  func supportedMarkerWinsWhenUnsupportedMetadataDoesNotMatchRequest() async throws {
    let clerk = Clerk()
    let middleware = makeMiddleware(for: clerk)
    clerk.appVersionSupportStatus = unsupportedStatus
    let request = try makeRequest(path: "/v1/client", sequence: 1)
    let response = try makeResponse(
      for: request,
      statusCode: 403,
      appVersionStatus: "supported"
    )

    await #expect(throws: ClerkAPIError.self) {
      try await middleware.validate(
        response,
        data: unsupportedPayload(appIdentifier: "com.example.different-app"),
        for: request
      )
    }

    #expect(clerk.appVersionSupportStatus == .supportedDefault)
  }

  @Test
  func unsupportedCodeOnNonForbiddenResponseDoesNotUpdateStatus() async throws {
    let clerk = Clerk()
    let middleware = makeMiddleware(for: clerk)
    let request = try makeRequest(path: "/v1/client", sequence: 1)
    let response = try makeResponse(for: request, statusCode: 409)

    await #expect(throws: ClerkAPIError.self) {
      try await middleware.validate(response, data: unsupportedPayload, for: request)
    }

    #expect(clerk.appVersionSupportStatus == .supportedDefault)
  }

  @Test
  func unsupportedResponseMustMatchRequestHeaders() async throws {
    let clerk = Clerk()
    let middleware = makeMiddleware(for: clerk)
    let request = try makeRequest(
      path: "/v1/client",
      sequence: 1,
      bundleID: "com.example.actual",
      appVersion: "1.0.1"
    )
    let response = try makeResponse(for: request, statusCode: 403)

    await #expect(throws: ClerkAPIError.self) {
      try await middleware.validate(
        response,
        data: unsupportedPayload(
          appIdentifier: "com.example.actual",
          currentVersion: "1.0.0"
        ),
        for: request
      )
    }

    #expect(clerk.appVersionSupportStatus == .supportedDefault)
  }

  @Test
  func unsupportedResponseRequiresAppIdentityAndVersionRequestHeaders() async throws {
    for missingHeader in [
      ClerkHeaderRequestMiddleware.bundleIDHeader,
      ClerkHeaderRequestMiddleware.appVersionHeader,
    ] {
      let clerk = Clerk()
      let middleware = makeMiddleware(for: clerk)
      var request = try makeRequest(path: "/v1/client", sequence: 1)
      request.setValue(nil, forHTTPHeaderField: missingHeader)
      let response = try makeResponse(for: request, statusCode: 403)

      await #expect(throws: ClerkAPIError.self) {
        try await middleware.validate(response, data: unsupportedPayload, for: request)
      }

      #expect(clerk.appVersionSupportStatus == .supportedDefault)
    }
  }

  private var unsupportedPayload: Data {
    unsupportedPayload(appIdentifier: "com.example.force-update")
  }

  private var apiErrorPayload: Data {
    Data(
      """
      {
        "errors": [{
          "code": "form_param_invalid",
          "message": "The request was invalid"
        }]
      }
      """.utf8
    )
  }

  private func unsupportedPayload(
    appIdentifier: String,
    currentVersion: String = "1.0.0"
  ) -> Data {
    Data(
      """
      {
        "errors": [{
          "code": "unsupported_app_version",
          "message": "Unsupported app version",
          "meta": {
            "platform": "ios",
            "app_identifier": "\(appIdentifier)",
            "current_version": "\(currentVersion)",
            "minimum_version": "2.0.0",
            "update_url": "https://apps.apple.com/app/id123"
          }
        }]
      }
      """.utf8
    )
  }

  private var unsupportedStatus: Clerk.AppVersionSupportStatus {
    .init(
      isSupported: false,
      minimumVersion: "999.0.0",
      updateURL: URL(string: "https://apps.apple.com/app/id123")
    )
  }

  private static func environment(
    bundleID: String,
    minimumVersion: String
  ) -> Clerk.Environment {
    var environment = Clerk.Environment.mock
    environment.nativeAppSettings = .init(
      minimumSupportedVersion: .init(
        ios: [
          .init(
            bundleId: bundleID,
            minimumVersion: minimumVersion,
            updateUrl: "https://apps.apple.com/app/id123"
          ),
        ]
      )
    )
    return environment
  }

  private func makeMiddleware(for clerk: Clerk) -> ClerkErrorThrowingResponseMiddleware {
    ClerkErrorThrowingResponseMiddleware(
      runtimeScope: .current { clerk },
      logNetworkError: { _, _, _ in }
    )
  }

  private func makeRequest(
    path: String,
    sequence: Int,
    bundleID: String = "com.example.force-update",
    appVersion: String = "1.0.0"
  ) throws -> URLRequest {
    let url = try #require(URL(string: "https://example.com\(path)"))
    var request = URLRequest(url: url)
    request.setClerkRequestSequence(sequence)
    request.setValue(
      bundleID,
      forHTTPHeaderField: ClerkHeaderRequestMiddleware.bundleIDHeader
    )
    request.setValue(
      appVersion,
      forHTTPHeaderField: ClerkHeaderRequestMiddleware.appVersionHeader
    )
    return request
  }

  private func makeResponse(
    for request: URLRequest,
    statusCode: Int,
    appVersionStatus: String? = nil
  ) throws -> HTTPURLResponse {
    let url = try #require(request.url)
    let headerFields = appVersionStatus.map {
      [ClerkErrorThrowingResponseMiddleware.appVersionStatusHeader: $0]
    }
    return try #require(
      HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: headerFields)
    )
  }
}
