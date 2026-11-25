//
//  NativeToWebView.swift
//  E2EHost
//

import ClerkKit
import SwiftUI
import WebKit

struct NativeToWebView: View {
  enum WebSession: Equatable {
    case loading
    case signedIn(userId: String)
    case signedOut
    case failed(code: String)
  }

  @Environment(Clerk.self) private var clerk

  let onDone: () -> Void

  @State private var webSession = WebSession.loading

  var body: some View {
    VStack(spacing: 12) {
      HStack {
        status
          .font(.footnote)

        Spacer()

        Button("Done", action: onDone)
          .accessibilityIdentifier(E2EIdentifiers.NativeToWeb.done)
      }
      .padding(.horizontal)

      SessionTransferWebView(clerk: clerk, destination: accountPortalUserPage, webSession: $webSession)
    }
  }

  @ViewBuilder
  private var status: some View {
    switch webSession {
    case .loading:
      Text("Loading the Account Portal")
    case .signedIn(let userId):
      HStack(spacing: 4) {
        Text("Web user ID")

        Text(userId)
          .accessibilityIdentifier(E2EIdentifiers.NativeToWeb.webUserId)
      }
    case .signedOut:
      Text("Signed out on the web")
    case .failed(let code):
      HStack(spacing: 4) {
        Text("Transfer failed")

        Text(code)
          .foregroundStyle(.red)
          .accessibilityIdentifier(E2EIdentifiers.NativeToWeb.error)
      }
    }
  }

  private var accountPortalUserPage: URL? {
    guard let homeUrl = clerk.environment?.displayConfig.homeUrl,
          var components = URLComponents(string: homeUrl)
    else {
      return nil
    }

    components.path = "/user"
    components.query = nil
    components.fragment = nil
    return components.url
  }
}

private struct SessionTransferWebView: UIViewRepresentable {
  let clerk: Clerk
  let destination: URL?
  @Binding var webSession: NativeToWebView.WebSession

  func makeCoordinator() -> Coordinator {
    Coordinator(webSession: $webSession)
  }

  func makeUIView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .nonPersistent()
    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = context.coordinator
    context.coordinator.startTransfer(in: webView, clerk: clerk, destination: destination)
    return webView
  }

  func updateUIView(_: WKWebView, context _: Context) {}

  static func dismantleUIView(_: WKWebView, coordinator: Coordinator) {
    coordinator.transfer?.cancel()
  }

  final class Coordinator: NSObject, WKNavigationDelegate {
    private static let signedInUserIdScript = """
    while (!window.Clerk?.loaded) {
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    return window.Clerk.user?.id ?? null;
    """

    private let webSession: Binding<NativeToWebView.WebSession>
    private var latestNavigation: WKNavigation?
    private(set) var transfer: Task<Void, Never>?

    init(webSession: Binding<NativeToWebView.WebSession>) {
      self.webSession = webSession
    }

    func startTransfer(in webView: WKWebView, clerk: Clerk, destination: URL?) {
      transfer = Task {
        guard let destination else {
          webSession.wrappedValue = .failed(code: "no_destination")
          return
        }

        do {
          try await clerk.auth.loadInWebView(webView, destination: destination)
        } catch let error as ClerkAPIError {
          webSession.wrappedValue = .failed(code: error.code)
        } catch {
          webSession.wrappedValue = .failed(code: "load_failed")
        }
      }
    }

    func webView(_: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
      if let failureCode = Self.sessionTransferFailureCode(in: navigationAction.request.url) {
        latestNavigation = nil
        webSession.wrappedValue = .failed(code: failureCode)
      }
      return .allow
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      if case .failed = webSession.wrappedValue {
        return
      }

      latestNavigation = navigation
      Task {
        let userId: Any?
        do {
          userId = try await webView.callAsyncJavaScript(Self.signedInUserIdScript, contentWorld: .page)
        } catch {
          return
        }

        guard navigation === latestNavigation else {
          return
        }

        webSession.wrappedValue = (userId as? String).map { .signedIn(userId: $0) } ?? .signedOut
      }
    }

    private static func sessionTransferFailureCode(in url: URL?) -> String? {
      guard let url, let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
            queryItems.contains(where: { $0.name == "__clerk_status" && $0.value == "session_transfer_failed" })
      else {
        return nil
      }

      return queryItems.first { $0.name == "__clerk_error_code" }?.value ?? "unknown"
    }
  }
}
