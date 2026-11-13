@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
import Testing

#if canImport(WebKit)
import WebKit
#endif

private let mintedUrlString = "https://clerk.example.invalid/v1/session_transfers/redeem?token=sttk_secret_123"
private let mintedToken = "sttk_secret_123"
private let expiresAtMilliseconds: Int64 = 1_767_225_600_000
private let expectedExpiresAt = Date(timeIntervalSince1970: 1_767_225_600)

struct SessionTransferTests {
  @Test
  func presentationUsesWireValues() {
    #expect(SessionTransferPresentation.webView.rawValue == "webview")
    #expect(SessionTransferPresentation.browser.rawValue == "browser")
  }

  @Test
  func resourceDecodesUrlAndMillisecondExpiry() throws {
    let data = try #require("""
    {"object":"session_transfer","url":"\(mintedUrlString)","expires_at":\(expiresAtMilliseconds)}
    """.data(using: .utf8))

    let transfer = try JSONDecoder.clerkDecoder.decode(SessionTransferResource.self, from: data).sessionTransfer()

    #expect(transfer.url.absoluteString == mintedUrlString)
    #expect(transfer.expiresAt == expectedExpiresAt)
  }

  @Test(arguments: [
    ("client", mintedUrlString),
    ("session_transfer", "http://clerk.example.invalid/v1/session_transfers/redeem?token=sttk_secret_123"),
    ("session_transfer", "https://user@clerk.example.invalid/v1/session_transfers/redeem"),
    ("session_transfer", "https://user:password@clerk.example.invalid/v1/session_transfers/redeem"),
    ("session_transfer", "https:missing-host"),
    ("session_transfer", "https:///v1/session_transfers/redeem"),
    ("session_transfer", "myapp://callback"),
  ])
  func resourceRejectsInvalidResponses(object: String, url: String) {
    let resource = SessionTransferResource(object: object, url: url, expiresAt: expectedExpiresAt)

    #expect(throws: ClerkClientError.self, "Expected response to be rejected: \(object) \(url)") {
      try resource.sessionTransfer()
    }
  }

  @Test(arguments: [
    "https://app.example.com/settings",
    "http://localhost:3000/settings",
    "HTTPS://app.example.com/settings",
  ])
  func createParamsAcceptHttpAndHttpsDestinations(rawValue: String) throws {
    let destination = try #require(URL(string: rawValue))

    let params = try SessionTransferCreateParams(destination: destination, presentation: .browser)

    #expect(params.redirectUrl == rawValue)
    #expect(params.presentationMode == .browser)
  }

  @Test(arguments: [
    "myapp://x",
    "/settings",
    "settings",
    "https:missing-host",
    "ftp://app.example.com/settings",
  ])
  func createParamsRejectNonWebOrRelativeDestinations(rawValue: String) throws {
    let destination = try #require(URL(string: rawValue))

    do {
      _ = try SessionTransferCreateParams(destination: destination, presentation: .webView)
      Issue.record("Expected destination to be rejected: \(rawValue)")
    } catch let error as ClerkClientError {
      #expect(error.message == "Session transfer requires an absolute http or https destination URL.")
    }
  }

  @Test
  func descriptionsAndMirrorHideTheUrl() throws {
    let transfer = try SessionTransfer(url: #require(URL(string: mintedUrlString)), expiresAt: expectedExpiresAt)
    var dumped = ""
    dump(transfer, to: &dumped)

    for rendered in [
      String(describing: transfer),
      String(reflecting: transfer),
      "\(transfer)",
      dumped,
    ] {
      #expect(!rendered.contains(mintedToken), "Rendered transfer leaked its token: \(rendered)")
      #expect(!rendered.contains("clerk.example.invalid"), "Rendered transfer leaked its URL: \(rendered)")
      #expect(rendered.contains("expiresAt"), "Rendered transfer dropped expiresAt: \(rendered)")
    }
    #expect(String(describing: transfer).contains(String(describing: expectedExpiresAt)))
  }
}

@MainActor
@Suite(.serialized)
struct SessionTransferRequestTests {
  @Test(arguments: [
    (SessionTransferPresentation.webView, "webview"),
    (SessionTransferPresentation.browser, "browser"),
  ])
  func prepareSendsFormPostForTheActiveSession(presentation: SessionTransferPresentation, wireValue: String) async throws {
    let sessionId = try signInForTesting()
    let destination = try #require(URL(string: "https://app.example.com/settings?tab=billing"))
    let requestHandled = LockIsolated(false)
    var mock = try sessionTransferMock(sessionId: sessionId)
    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(request.url?.path == "/v1/client/sessions/\(sessionId)/session_transfers")
      #expect(!request.shouldLogClerkBodies)
      let queryItems = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems }
      #expect(queryItems == [
        URLQueryItem(name: "_is_native", value: "true"),
      ])
      #expect(request.urlEncodedFormBody == [
        "redirect_url": "https://app.example.com/settings?tab=billing",
        "presentation_mode": wireValue,
      ])
      requestHandled.setValue(true)
    }
    mock.register()

    let transfer = try await Clerk.shared.auth.prepareSessionTransfer(destination: destination, presentation: presentation)

    #expect(requestHandled.value)
    #expect(transfer.url.absoluteString == mintedUrlString)
    #expect(transfer.expiresAt == expectedExpiresAt)
  }

  @Test
  func prepareLogsNeitherTheUrlNorTheTokenAtVerboseLevel() async throws {
    let sessionId = try signInForTesting()
    try Clerk.shared.dependencies.configurationManager.configure(publishableKey: testPublishableKey, options: Clerk.Options(logLevel: .verbose))
    try sessionTransferMock(sessionId: sessionId).register()
    let (lines, restoreSink) = captureLogLines()
    defer { restoreSink() }

    _ = try await Clerk.shared.auth.prepareSessionTransfer(
      destination: #require(URL(string: "https://app.example.com/settings")),
      presentation: .webView
    )

    try await #require(lines.firstLine(containing: "Response: 200 POST") != nil)
    try await Task.sleep(for: .milliseconds(100))
    for line in lines.value {
      #expect(!line.contains(mintedToken), "Log line leaked the token: \(line)")
      #expect(!line.contains("clerk.example.invalid"), "Log line leaked the URL: \(line)")
    }
  }

  @Test
  func prepareRejectsAnInvalidResponseBody() async throws {
    let sessionId = try signInForTesting()
    try sessionTransferMock(sessionId: sessionId, url: "http://clerk.example.invalid/v1/session_transfers/redeem").register()

    do {
      _ = try await Clerk.shared.auth.prepareSessionTransfer(
        destination: #require(URL(string: "https://app.example.com/settings")),
        presentation: .webView
      )
      Issue.record("Expected an http transfer URL to be rejected.")
    } catch let error as ClerkClientError {
      #expect(error.message == "Session transfer creation returned an invalid response.")
    }
  }

  @Test(arguments: ["myapp://x", "/settings"])
  func prepareRejectsInvalidDestinationWithoutARequest(rawValue: String) async throws {
    let transport = useFakeTransport(client: .mock)
    let destination = try #require(URL(string: rawValue))

    await #expect(throws: ClerkClientError.self) {
      try await Clerk.shared.auth.prepareSessionTransfer(destination: destination, presentation: .webView)
    }
    #expect(transport.calls.isEmpty)
  }

  @Test
  func prepareRequiresASessionWithoutARequest() async throws {
    let transport = useFakeTransport(client: .mockSignedOut)
    #expect(Clerk.shared.session == nil)

    do {
      _ = try await Clerk.shared.auth.prepareSessionTransfer(
        destination: #require(URL(string: "https://app.example.com/settings")),
        presentation: .webView
      )
      Issue.record("Expected a signed-out client to be rejected.")
    } catch let error as ClerkClientError {
      #expect(error.message == "Session transfer requires an active session.")
    }
    #expect(transport.calls.isEmpty)
  }

  @Test
  func prepareTreatsAPendingSessionAsSignedOut() async throws {
    var client = Client.mock
    let index = try #require(client.sessions.firstIndex { $0.id == client.lastActiveSessionId })
    client.sessions[index].status = .pending
    let transport = useFakeTransport(client: client)
    #expect(Clerk.shared.session?.status == .pending)

    await #expect(throws: ClerkClientError.self) {
      try await Clerk.shared.auth.prepareSessionTransfer(
        destination: #require(URL(string: "https://app.example.com/settings")),
        presentation: .browser
      )
    }
    #expect(transport.calls.isEmpty)
  }

  @Test
  func prepareSurfacesFeatureNotEnabledAsAnAPIError() async throws {
    let sessionId = try signInForTesting()
    let requestUrl = try #require(URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(sessionId)/session_transfers"))
    let errorBody = try #require("""
    {"errors":[{"message":"not enabled","long_message":"This feature is not enabled on this instance","code":"feature_not_enabled"}],"clerk_trace_id":"trace_123"}
    """.data(using: .utf8))
    Mock(url: requestUrl, ignoreQuery: true, contentType: .json, statusCode: 403, data: [.post: errorBody]).register()

    do {
      _ = try await Clerk.shared.auth.prepareSessionTransfer(
        destination: #require(URL(string: "https://app.example.com/settings")),
        presentation: .webView
      )
      Issue.record("Expected feature_not_enabled to throw.")
    } catch let error as ClerkAPIError {
      #expect(error.code == "feature_not_enabled")
      #expect(error.clerkTraceId == "trace_123")
    }
  }

  @Test
  func openInBrowserMintsABrowserTransferAndOpensItsUrl() async throws {
    let sessionId = try signInForTesting()
    let presentationMode = LockIsolated<String?>(nil)
    let openedUrl = LockIsolated<URL?>(nil)
    var mock = try sessionTransferMock(sessionId: sessionId)
    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      presentationMode.setValue(request.urlEncodedFormBody?["presentation_mode"])
    }
    mock.register()

    try await Clerk.shared.auth.openInBrowser(destination: #require(URL(string: "https://app.example.com/settings"))) { url in
      openedUrl.setValue(url)
      return true
    }

    #expect(presentationMode.value == "browser")
    #expect(openedUrl.value?.absoluteString == mintedUrlString)
  }

  @Test
  func openInBrowserThrowsWhenNoBrowserOpensTheUrl() async throws {
    let sessionId = try signInForTesting()
    try sessionTransferMock(sessionId: sessionId).register()

    do {
      try await Clerk.shared.auth.openInBrowser(destination: #require(URL(string: "https://app.example.com/settings"))) { _ in
        false
      }
      Issue.record("Expected a refused open to throw.")
    } catch let error as ClerkClientError {
      #expect(error.message == "No browser could open the sign-in link.")
    }
  }

  @Test
  func openInBrowserOpensNothingWhenCancelledAfterTheTransferIsCreated() async throws {
    let transport = useFakeTransport(client: .mock)
    try stubTransferThatCancelsTheCallingTask(on: transport)
    let opened = LockIsolated(false)
    let destination = try #require(URL(string: "https://app.example.com/settings"))

    let result = await Task {
      try await Clerk.shared.auth.openInBrowser(destination: destination) { _ in
        opened.setValue(true)
        return true
      }
    }.result

    #expect(throws: CancellationError.self) { try result.get() }
    #expect(transport.calls.count == 1)
    #expect(!opened.value)
  }

  #if canImport(WebKit)
  @Test
  func loadInWebViewMintsAWebViewTransferAndLoadsItsUrl() async throws {
    let sessionId = try signInForTesting()
    let presentationMode = LockIsolated<String?>(nil)
    var mock = try sessionTransferMock(sessionId: sessionId)
    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      presentationMode.setValue(request.urlEncodedFormBody?["presentation_mode"])
    }
    mock.register()
    let webView = WKWebView()
    defer { webView.stopLoading() }

    try await Clerk.shared.auth.loadInWebView(webView, destination: #require(URL(string: "https://app.example.com/settings")))

    #expect(presentationMode.value == "webview")
    #expect(webView.url?.absoluteString == mintedUrlString)
  }

  @Test
  func loadInWebViewLoadsNothingWhenCancelledAfterTheTransferIsCreated() async throws {
    let transport = useFakeTransport(client: .mock)
    try stubTransferThatCancelsTheCallingTask(on: transport)
    let webView = WKWebView()
    let destination = try #require(URL(string: "https://app.example.com/settings"))

    let result = await Task {
      try await Clerk.shared.auth.loadInWebView(webView, destination: destination)
    }.result

    #expect(throws: CancellationError.self) { try result.get() }
    #expect(transport.calls.count == 1)
    #expect(webView.url == nil)
  }
  #endif

  private func signInForTesting() throws -> String {
    configureClerkForTesting()
    Clerk.shared.client = .mock
    return try #require(Clerk.shared.activeSession?.id)
  }

  private func useFakeTransport(client: Client) -> FakeTransport {
    configureClerkForTesting()
    let transport = FakeTransport()
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      transport: transport
    )
    Clerk.shared.client = client
    return transport
  }

  private func stubTransferThatCancelsTheCallingTask(on transport: FakeTransport) throws {
    let params = try SessionTransferCreateParams(destination: #require(URL(string: "https://app.example.com")), presentation: .browser)
    transport.stub(SessionTransferAPI.create(sessionId: FakeTransport.anyPathSegment, params: params)) { _ in
      withUnsafeCurrentTask { $0?.cancel() }
      return ClientResponse(
        response: SessionTransferResource(object: "session_transfer", url: mintedUrlString, expiresAt: expectedExpiresAt),
        client: nil
      )
    }
  }

  private func sessionTransferMock(sessionId: String, url: String = mintedUrlString) throws -> Mock {
    let requestUrl = try #require(URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(sessionId)/session_transfers"))
    let client = try JSONSerialization.jsonObject(with: JSONEncoder.clerkEncoder.encode(Client.mock))
    let body = try JSONSerialization.data(withJSONObject: [
      "response": [
        "object": "session_transfer",
        "url": url,
        "expires_at": expiresAtMilliseconds,
      ],
      "client": client,
    ])
    return Mock(url: requestUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [.post: body])
  }
}

extension LockIsolated<[String]> {
  fileprivate func firstLine(containing needle: String) async -> String? {
    for _ in 0 ..< 100 {
      if let line = value.first(where: { $0.contains(needle) }) {
        return line
      }
      try? await Task.sleep(for: .milliseconds(10))
    }
    return nil
  }
}

@MainActor
private func captureLogLines() -> (LockIsolated<[String]>, @MainActor () -> Void) {
  let original = ClerkLogger.sink
  let lines = LockIsolated<[String]>([])
  ClerkLogger.sink = { _, text in
    lines.withValue { $0.append(text) }
  }
  return (lines, { ClerkLogger.sink = original })
}
